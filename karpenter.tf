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

    root_volume_size = try(var.karpenter.root_volume_size, "4Gi")
    data_volume_size = try(var.karpenter.data_volume_size, "20Gi")
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.34.0"

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
  source = "./modules/addon"

  chart            = "karpenter-crd"
  chart_version    = "1.0.8" # github-releases/aws/karpenter-provider-aws
  repository       = "oci://public.ecr.aws/karpenter"
  description      = "Karpenter CRDs"
  namespace        = local.karpenter.namespace
  create_namespace = true
}


module "karpenter_release" {
  source = "./modules/addon"

  chart            = "karpenter"
  chart_version    = "1.0.8" # github-releases/aws/karpenter-provider-aws
  repository       = "oci://public.ecr.aws/karpenter"
  namespace        = local.karpenter.namespace
  create_namespace = true
  skip_crds        = true
  wait             = true

  values = [
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
    serviceMonitor:
      enabled: ${module.prometheus_operator_crds.create}
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
  ]

  set = try(var.karpenter.set, [])

  additional_delay_destroy_duration = "1m"

  additional_helm_releases = {
    karpenter_node_class = {
      description   = "Karpenter NodeClass Resource"
      chart         = "custom-resources"
      chart_version = "0.1.2"
      repository    = "https://dnd-it.github.io/helm-charts"

      values = [
        <<-EOT
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        metadata:
          name: default
        spec:
          # Required so containers can access node metadata
          metadataOptions:
            httpPutResponseHopLimit: 2
          amiSelectorTerms:
            - alias: bottlerocket@latest
          role: ${module.karpenter.node_iam_role_name}
          subnetSelectorTerms:
            - tags:
                karpenter.sh/discovery: ${module.eks.cluster_name}
          securityGroupSelectorTerms:
            - tags:
                karpenter.sh/discovery: ${module.eks.cluster_name}
          blockDeviceMappings:
            - deviceName: /dev/xvda
              ebs:
                volumeSize: ${local.karpenter.root_volume_size}
                volumeType: gp3
                encrypted: true
                deleteOnTermination: true
            - deviceName: /dev/xvdb
              ebs:
                volumeSize: ${local.karpenter.data_volume_size}
                volumeType: gp3
                encrypted: true
                deleteOnTermination: true
          tags:
            environment: ${var.metadata.environment}
            team: ${var.metadata.team}
        EOT
      ]

      set = try(var.karpenter.additional_helm_releases.karpenter_node_class.set, [])
    }
    karpenter_node_pool = {
      description   = "Karpenter NodePool Resource"
      chart         = "custom-resources"
      chart_version = "0.1.2"
      repository    = "https://dnd-it.github.io/helm-charts"

      values = [
        <<-EOT
        apiVersion: karpenter.sh/v1
        kind: NodePool
        metadata:
          name: default
        spec:
          template:
            spec:
              nodeClassRef:
                name: default
                kind: EC2NodeClass
                group: karpenter.k8s.aws
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
                  values: ["2048"]
                - key: "karpenter.sh/capacity-type"
                  operator: In
                  values: ["spot", "on-demand"]
                - key: "karpenter.k8s.aws/instance-generation"
                  operator: Gt
                  values: ["2"]
              expireAfter: 720h
          limits:
            cpu: "1000"
          disruption:
            consolidationPolicy: WhenEmptyOrUnderutilized
            consolidateAfter: 1m
        EOT
      ]

      set = try(var.karpenter.additional_helm_releases.karpenter_node_pool.set, [])
    }
  }

  depends_on = [
    # service monitor depends on prometheus operator CRDs
    module.prometheus_operator_crds,
    module.karpenter_crds,
    module.karpenter,
    module.karpenter_security_group,
    aws_subnet.karpenter,
    aws_route_table_association.karpenter
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
