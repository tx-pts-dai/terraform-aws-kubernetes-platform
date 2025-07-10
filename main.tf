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
  id = format("%08x", time_static.timestamp_id.unix)

  # This is not the best way to handle naming compatibility but its a simple approach to fix renovate PR deployments
  name       = coalesce(replace(var.name, "/", "-"), replace(basename(path.root), "_", "-"))
  stack_name = "${local.name}-${local.id}"

  tags = merge(var.tags, {
    StackName = local.stack_name
  })

  region = data.aws_region.current.name
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
  k8s_version = trimspace(file("${path.module}/K8S_VERSION"))
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  cluster_name                    = local.stack_name
  cluster_version                 = local.k8s_version
  cluster_endpoint_public_access  = try(var.eks.cluster_endpoint_public_access, true)
  cluster_endpoint_private_access = try(var.eks.cluster_endpoint_private_access, true)

  cluster_addons = {
    vpc-cni = {
      most_recent = true
      preserve    = true

      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn

      configurationsi_values = {
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      }
    }

    kube-proxy = {
      most_recent = true
      preserve    = true
    }
  }

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

# Allows all traffic from the VPC to the EKS control plane
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

resource "aws_security_group_rule" "eks_control_plane_ingress" {
  for_each = local.ingress_rules

  security_group_id = module.eks.cluster_primary_security_group_id
  description       = each.value.description
  type              = each.value.type
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = each.value.cidr_blocks

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# VPC CNI IAM Role for Service Accounts

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.55.0"

  role_name = "vpc-cni-${local.id}"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

resource "time_sleep" "wait_on_destroy" {
  depends_on = [
    module.acm,
    module.eks,
    module.karpenter,
    helm_release.karpenter_crd,
    helm_release.karpenter_release,
    module.karpenter_security_group,
    aws_subnet.karpenter,
    aws_route_table_association.karpenter,
  ]

  # Sleep for 5 minutes to allow Karpenter to clean up resources
  destroy_duration = "5m"
}
