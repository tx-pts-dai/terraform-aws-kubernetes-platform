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

    namespace               = "kube-system"
    replicas                = try(var.karpenter.replicas, 1)
    service_monitor_enabled = try(var.karpenter.service_monitor_enabled, true)
    pod_annotations         = try(var.karpenter.pod_annotations, {})
    cpu_request             = try(var.karpenter.cpu_request, 0.25)
    memory_request          = try(var.karpenter.memory_request, "256Mi")
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.20.0"

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

module "karpenter_crds" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name             = "karpenter-crd"
  namespace        = local.karpenter.namespace
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  chart_version    = "0.37.0"
}


resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = local.karpenter.namespace
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "0.37.0"
  skip_crds        = true
  wait             = true

  values = [
    <<-EOT
    logLevel: info
    dnsPolicy: Default
    replicas: "${local.karpenter.replicas}"
    podAnnotations: ${jsonencode(local.karpenter.pod_annotations)}
    controller:
      resources:
        requests:
          cpu: ${local.karpenter.cpu_request}
          memory: ${local.karpenter.memory_request}
    serviceMonitor:
      enabled: ${var.prometheus_stack.enabled}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    EOT
  ]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    module.karpenter_crds
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r", "t"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["2", "4", "8", "16", "32"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-memory"
              operator: Gt
              values: ["1024"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot", "on-demand"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["2"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 720h
  YAML

  depends_on = [
    module.karpenter_crds
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
