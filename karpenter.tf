################################################################################
# Karpenter
#
# Track notes here for future reference e.g. reasons for certain decisions
# - PROPOSAL: Karpenter NodePool and EC2NodeClass management: default resources are deployed with the module.
#   Users can create additional resources by providing their own ones outside the module.
# TODO: Move the Karpenter resources to a submodule

locals {
  karpenter = {
    subnet_cidrs = try(var.karpenter.subnet_cidrs, module.network.grouped_networks.karpenter)

    namespace = "kube-system"
    # TODO: move to helm value inputs
    pod_annotations = try(var.karpenter.pod_annotations, {})
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.35.0"

  cluster_name                    = module.eks.cluster_name
  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["${local.karpenter.namespace}:karpenter"]
  iam_role_name                   = "karpenter-${local.id}"
  iam_role_use_name_prefix        = false

  node_iam_role_name              = "karpenter-node-${local.id}"
  node_iam_role_use_name_prefix   = false
  node_iam_role_attach_cni_policy = false
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  chart            = "karpenter-crd"
  version          = "1.0.8"
  repository       = "oci://public.ecr.aws/karpenter"
  description      = "Karpenter CRDs"
  namespace        = local.karpenter.namespace
  create_namespace = true
}


resource "helm_release" "karpenter_release" {
  name             = "karpenter"
  chart            = "karpenter"
  version          = "1.0.8"
  repository       = "oci://public.ecr.aws/karpenter"
  namespace        = local.karpenter.namespace
  create_namespace = true
  skip_crds        = true
  wait             = true

  values = concat([
    <<-EOT
    logLevel: info
    dnsPolicy: Default
    replicas: 2
    podAnnotations: ${jsonencode(local.karpenter.pod_annotations)}
    controller:
      resources:
        requests:
          cpu: 0.5
          memory: "512Mi"
    settings:
      eksControlPlane: true
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
      featureGates:
        spotToSpotConsolidation: true
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    EOT
  ], try(var.karpenter.values, []))

  dynamic "set" {
    for_each = try(var.karpenter.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  depends_on = [
    helm_release.karpenter_crd,
    module.karpenter,
    module.karpenter_security_group,
    aws_subnet.karpenter,
    aws_route_table_association.karpenter
  ]
}

resource "helm_release" "karpenter_resources" {
  name       = "karpenter-resources"
  chart      = "karpenter-resources"
  version    = "0.3.1"
  repository = "https://dnd-it.github.io/helm-charts"
  namespace  = local.karpenter.namespace

  values = concat([
    <<-EOT
    global:
      role: ${module.karpenter.node_iam_role_name}
      eksDiscovery:
        enabled: true
        clusterName: ${module.eks.cluster_name}

    nodePools:
      default:
        enabled: true

    ec2NodeClasses:
      default:
        enabled: true
    EOT
  ], try(var.karpenter.karpenter_resources.values, []))

  dynamic "set" {
    for_each = try(var.karpenter.karpenter_resources.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  depends_on = [
    helm_release.karpenter_release
  ]
}

###############################################################################
# Karpenter Networking

resource "aws_subnet" "karpenter" {
  count = length(local.karpenter.subnet_cidrs)

  vpc_id            = local.vpc.vpc_id
  cidr_block        = local.karpenter.subnet_cidrs[count.index]
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name                     = "${module.eks.cluster_name}-karpenter-${element(local.azs, count.index)}"
    "karpenter.sh/discovery" = module.eks.cluster_name
  })
}

data "aws_route_tables" "private_route_tables" {
  vpc_id = local.vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

resource "aws_route_table_association" "karpenter" {
  count = length(local.karpenter.subnet_cidrs)

  subnet_id      = aws_subnet.karpenter[count.index].id
  route_table_id = try(data.aws_route_tables.private_route_tables.ids[count.index], data.aws_route_tables.private_route_tables.ids[0], "") # Depends on the number of Nat Gateways
}

module "karpenter_security_group" {
  source = "./modules/security-group"

  name        = "karpenter-default-${local.stack_name}"
  description = "Karpenter default security group"

  vpc_id = local.vpc.vpc_id

  ingress_rules = {
    self_all = {
      type      = "ingress"
      protocol  = "-1"
      from_port = 0
      to_port   = 65535
      self      = true
    }
    control_plane_other = {
      type                     = "ingress"
      protocol                 = "TCP"
      from_port                = 1025
      to_port                  = 65535
      source_security_group_id = module.eks.cluster_primary_security_group_id
    }
    vpc_all = {
      type        = "ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      cidr_blocks = [local.vpc.vpc_cidr]
    }
  }
  egress_rules = {
    all = {
      type        = "egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = merge(local.tags, {
    # Is this needed? AWS LB Controller uses this to add itself to the node security groups
    "kubernetes.io/cluster/${local.stack_name}" = "owned"
    "karpenter.sh/discovery"                    = local.stack_name
  })
}
