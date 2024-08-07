################################################################################
# TAMEDIA KUBERNETES AS A SERVICE (TKaaS)
#
# Batteries included Kubernetes clusters.
#
# main.tf
# This file is the entrypoint for the TKaaS module. It is responsible for
# orchestrating the creation of the Kubernetes cluster and Karpenter resources.
################################################################################

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

# ID based on epoch timestamp for creating unique resources. Note: This is only
# generated on apply and is static for the life of the stack.
resource "time_static" "timestamp_id" {}

################################################################################
# Common locals
#
# Tidy up the naming here to be more consistent
# TODO: what happens if you dont pass a k8s version to the eks module. do you get latest?
# TODO: we cannot use the random id in the tags since it only gets generated after the resource is created
# and this create a tags merge issue,

locals {
  id         = format("%08x", time_static.timestamp_id.unix)
  name       = coalesce(var.name, replace(basename(path.root), "_", "-"))
  stack_name = "${local.name}-${local.id}"

  tags = merge(var.tags, {
    StackName = local.stack_name
  })
}

################################################################################
# VPC
#
# Notes
# The module should support passing in a vpc or creating one.
# If passing in a vpc, the module should support creating subnets.

# VPC  Resources
locals {
  vpc = {
    vpc_id          = try(var.vpc.vpc_id, module.network.vpc.vpc_id)
    vpc_cidr        = try(var.vpc.vpc_cidr, module.network.cidr)
    private_subnets = try(var.vpc.private_subnets, module.network.vpc.private_subnets)
    intra_subnets   = try(var.vpc.intra_subnets, module.network.vpc.intra_subnets)
  }
}

module "network" {
  source = "./modules/network"

  create_vpc = try(var.vpc.enabled, false)

  stack_name = local.stack_name

  tags = local.tags
}

################################################################################
# EKS Cluster
data "aws_iam_roles" "sso" {
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
  path_prefix = local.sso_path_prefix
}

data "aws_iam_roles" "iam_cluster_admins" {
  for_each = var.cluster_admins

  name_regex = "^${each.value.role_name}$"
}

locals {
  sso_path_prefix = "/aws-reserved/sso.amazonaws.com/"
  sso_cluster_admin = length(data.aws_iam_roles.sso.arns) == 1 ? {
    sso = {
      role_arn = tolist(data.aws_iam_roles.sso.arns)[0]
    }
  } : {}

  iam_cluster_admins = { for k, v in var.cluster_admins : k => {
    role_arn          = tolist(data.aws_iam_roles.iam_cluster_admins[k].arns)[0]
    kubernetes_groups = try(v.kubernetes_groups, null)
  } }

  cluster_admins = merge(local.sso_cluster_admin, local.iam_cluster_admins)

  access_entries = { for k, v in local.cluster_admins : k => {
    principal_arn     = v.role_arn
    type              = "STANDARD"
    kubernetes_groups = try(v.kubernetes_groups, null)

    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  } }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.20.0"

  cluster_name                    = local.stack_name
  cluster_version                 = try(var.eks.kubernetes_version, "1.29")
  cluster_endpoint_public_access  = try(var.eks.cluster_endpoint_public_access, true)
  cluster_endpoint_private_access = try(var.eks.cluster_endpoint_private_access, true)

  iam_role_name            = local.stack_name
  iam_role_use_name_prefix = false

  vpc_id                   = local.vpc.vpc_id
  subnet_ids               = local.vpc.private_subnets
  control_plane_subnet_ids = local.vpc.intra_subnets

  create_cluster_security_group = false
  create_node_security_group    = false

  enable_cluster_creator_admin_permissions = try(var.eks.enable_cluster_creator_admin_permissions, false)

  fargate_profiles = {
    karpenter = {
      selectors = [
        {
          namespace = local.karpenter.namespace
          labels    = { "app.kubernetes.io/name" = "karpenter" }
        },
      ]
      iam_role_name            = "karpenter-fargate-${local.id}"
      iam_role_use_name_prefix = false
    }
  }

  access_entries = local.access_entries

  tags = local.tags
}

# Allow all traffic from the VPC to the EKS control plane
locals {
  ingress_rules = {
    vpc_control_plane = {
      description = "Allow all traffic from the VPC to EKS managed workfloads over HTTPS"
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = [local.vpc.vpc_cidr]
    }
    vpc_other = {
      description = "Allow all traffic from the VPC to EKS managed workloads 1025-65535"
      type        = "ingress"
      protocol    = "-1"
      from_port   = 1025
      to_port     = 65535
      cidr_blocks = [local.vpc.vpc_cidr]
    }
  }
}

resource "aws_security_group_rule" "eks_control_plan_ingress" {
  for_each = local.ingress_rules

  security_group_id = module.eks.cluster_primary_security_group_id
  description       = each.value.description
  type              = each.value.type
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = each.value.cidr_blocks
}

################################################################################
# Karpenter
#
# Track notes here for future reference e.g. reasons for certain decisions
# - PROPOSAL: Karpenter NodePool and EC2NodeClass management: default resources are deployed with the module.
#   Users can create additional resources by providing their own ones outside the module.

locals {
  karpenter = {
    subnet_cidrs = try(var.karpenter.subnet_cidrs, module.network.grouped_networks.karpenter)

    namespace               = try(var.karpenter.namespace, "kube-system")
    chart_version           = try(var.karpenter.chart_version, "0.37.0")
    replicas                = try(var.karpenter.replicas, 1)
    service_monitor_enabled = try(var.karpenter.service_monitor_enabled, false)
    pod_annotations         = try(var.karpenter.pod_annotations, {})
    cpu_request             = try(var.karpenter.cpu_request, 0.25)
    memory_request          = try(var.karpenter.memory_request, "256Mi")
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

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

  create = var.enable_karpenter_crds

  name             = "karpenter-crd"
  namespace        = local.karpenter.namespace
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  chart_version    = local.karpenter.chart_version
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = local.karpenter.namespace
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = local.karpenter.chart_version
  skip_crds        = var.enable_karpenter_crds
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
      enabled: ${local.karpenter.service_monitor_enabled}
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
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    module.karpenter_crds
  ]
}

resource "time_sleep" "wait_on_destroy" {
  depends_on = [
    module.eks,
    module.karpenter,
    module.karpenter_crds,
    aws_subnet.karpenter,
    aws_route_table_association.karpenter,
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_class,
    kubectl_manifest.karpenter_node_pool,
  ]

  # Sleep for 10 minutes to allow Karpenter to clean up resources
  destroy_duration = "10m"
}
