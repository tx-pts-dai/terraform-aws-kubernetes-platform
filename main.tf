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
data "aws_caller_identity" "current" {}

# Random ID for creating unique resources instead of using a timestamp which is
# different accross resources. Note: This is only generated on apply and is
# static for the life of the stack.
resource "random_id" "random_id" {
  byte_length = 4
}

################################################################################
# Common locals
#
# Tidy up the naming here to be more consistent
# TODO: what happens if you dont pass a k8s version to the eks module. do you get latest?
# TODO: we cannot use the random id in the tags since it only gets generated after the resource is created
# and this create a tags merge issue,

locals {
  id         = random_id.random_id.hex
  name       = coalesce(var.name, replace(basename(path.root), "_", "-"))
  stack_name = "${local.name}-${local.id}"

  tags = merge(var.tags, {
  })
}

################################################################################
# VPC
#
# Notes
# The module should support passing in a vpc or creating one.
# If passing in a vpc, the module should support creating subnets.
# To start off with, lets not do too much magic and pass in subnet masks for the
# karpenter managed subnets.

# VPC  Resources
locals {
  vpc = {
    vpc_id          = try(var.vpc.vpc_id, module.network.vpc.vpc_id)
    private_subnets = try(var.vpc.private_subnets, module.network.vpc.private_subnets)
    intra_subnets   = try(var.vpc.intra_subnets, module.network.vpc.intra_subnets)
  }
}

module "network" {
  source = "./modules/network"

  create_vpc = try(var.vpc.create, false)

  cidr       = try(var.vpc.cidr, "10.0.0.0/16")
  stack_name = local.stack_name

  tags = local.tags
}

################################################################################
# EKS Cluster
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_roles" "sso" {
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
  path_prefix = local.sso_path_prefix
}

locals {
  sso_path_prefix   = "/aws-reserved/sso.amazonaws.com/"
  sso_cluster_admin = { for name in data.aws_iam_roles.sso.names : "sso" => { role_name = name.name } }
  cluster_admins    = merge(local.sso_cluster_admin, var.cluster_admins)

  access_entries = { for k, v in local.cluster_admins : k => {
    principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${v.role_name}"
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
  } if "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${v.role_name}" != data.aws_iam_session_context.current.issuer_arn }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.3"

  cluster_name                    = local.stack_name
  cluster_version                 = try(var.eks.kubernetes_version, "1.29")
  cluster_endpoint_public_access  = try(var.eks.cluster_endpoint_public_access, true)
  cluster_endpoint_private_access = try(var.eks.cluster_endpoint_private_access, false)

  iam_role_name            = local.stack_name
  iam_role_use_name_prefix = false

  vpc_id                   = local.vpc.vpc_id
  subnet_ids               = local.vpc.private_subnets
  control_plane_subnet_ids = local.vpc.intra_subnets

  create_cluster_security_group = false
  create_node_security_group    = false

  enable_cluster_creator_admin_permissions = true

  fargate_profiles = {
    karpenter = {
      selectors = [
        {
          namespace = "kube-system"
          labels    = { "app.kubernetes.io/name" = "karpenter" }
        },
      ]
      iam_role_name            = "karpenter-fargate-${local.id}"
      iam_role_use_name_prefix = false
    }
  }

  # TODO: remove duplicates in case of local deployment. If you are deploying from local
  access_entries = local.access_entries


  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.stack_name # TODO: Move to security group module when added
  })
}

################################################################################
# Karpenter
#
# Track notes here for future reference e.g. reasons for certain decisions
# - PROPOSAL: Karpenter NodePool and EC2NodeClass management: default resources are deployed with the module.
#   Users can create additional resources by providing their own ones outside the module.

data "aws_availability_zones" "available" {}

locals {
  karpenter = {
    chart_version           = try(var.karpenter.chart_version, "0.35.2")
    replicas                = try(var.karpenter.replicas, 1)
    service_monitor_enabled = try(var.karpenter.service_monitor_enabled, false)
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

resource "aws_subnet" "karpenter" {
  count = length(var.karpenter.subnet_cidrs)

  vpc_id            = local.vpc.vpc_id
  cidr_block        = var.karpenter.subnet_cidrs[count.index]
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
  count = length(var.karpenter.subnet_cidrs)

  subnet_id      = aws_subnet.karpenter[count.index].id
  route_table_id = try(data.aws_route_tables.private_route_tables.ids[count.index], data.aws_route_tables.private_route_tables.ids[0], "") # Depends on the number of Nat Gateways
}

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name                    = module.eks.cluster_name
  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["kube-system:karpenter"]
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

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  # rate limit is 1 pull per second
  # repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  # repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart   = "karpenter"
  version = local.karpenter.chart_version
  wait    = true

  values = [
    <<-EOT
    logLevel: info
    dnsPolicy: Default
    replicas: "${local.karpenter.replicas}"
    resources:
      requests:
        cpu: "0.25"
        memory: 256Mi
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

  depends_on = [
    module.karpenter
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
    helm_release.karpenter
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
    kubectl_manifest.karpenter_node_class
  ]
}

resource "time_sleep" "wait_on_destroy" {
  depends_on = [
    module.eks,
    module.karpenter,
    aws_subnet.karpenter,
    aws_route_table_association.karpenter,
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_class,
    kubectl_manifest.karpenter_node_pool,
  ]

  # Sleep for 5 minutes to allow Karpenter to clean up resources
  destroy_duration = "5m"
}
