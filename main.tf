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
data "aws_caller_identity" "current" {}

# ID based on epoch timestamp for creating unique resources. Note: This is only
# generated on apply and is static for the life of the stack.
resource "time_static" "timestamp_id" {
  count = var.enable_timestamp_id ? 1 : 0
}

################################################################################
# Common locals
#
# Tidy up the naming here to be more consistent
# TODO: what happens if you dont pass a k8s version to the eks module. do you get latest?
# TODO: we cannot use the random id in the tags since it only gets generated after the resource is created
# and this create a tags merge issue,

locals {
  id = var.enable_timestamp_id ? format("%08x", time_static.timestamp_id[0].unix) : local.name

  # This is not the best way to handle naming compatibility but its a simple approach to fix renovate PR deployments
  name       = coalesce(replace(var.name, "/", "-"), replace(basename(path.root), "_", "-"))
  stack_name = local.id != local.name ? "${local.name}-${local.id}" : local.name

  tags = merge(var.tags, {
    StackName = local.stack_name
  })

  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
}

################################################################################
# EKS Cluster
data "aws_iam_roles" "sso" {
  count = var.enable_sso_admin_auto_discovery ? 1 : 0

  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
  path_prefix = local.sso_path_prefix
}

data "aws_iam_roles" "iam_cluster_admins" {
  for_each = var.cluster_admins

  name_regex = "^${each.value.role_name}$"
}

locals {
  sso_path_prefix = "/aws-reserved/sso.amazonaws.com/"
  sso_cluster_admin = var.enable_sso_admin_auto_discovery && length(data.aws_iam_roles.sso) > 0 && length(data.aws_iam_roles.sso[0].arns) == 1 ? {
    sso = {
      role_arn = tolist(data.aws_iam_roles.sso[0].arns)[0]
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
  version = "21.1.5"

  name                    = local.stack_name
  kubernetes_version      = local.k8s_version
  endpoint_public_access  = try(var.eks.cluster_endpoint_public_access, true)
  endpoint_private_access = try(var.eks.cluster_endpoint_private_access, true)
  authentication_mode     = "API"

  addons = {
    vpc-cni = {
      most_recent = true
      preserve    = true

      service_account_role_arn = module.vpc_cni_irsa.arn

      configuration_values = jsonencode({ env = { ENABLE_PREFIX_DELEGATION = "true" } })
    }

    kube-proxy = {
      most_recent = true
      preserve    = true
    }

    eks-pod-identity-agent = {
      before_compute = true

      most_recent = true
      preserve    = true

      timeouts = {
        create = "3m"
        delete = "3m"
      }
    }

    # coredns = {
    #   before_compute = true

    #   most_recent = true
    #   preserve    = false

    #   timeouts = {
    #     create = "3m"
    #     delete = "3m"
    #   }
    # }

    # aws-ebs-csi-driver = {
    #   before_compute = true

    #   most_recent = true
    #   preserve    = false

    #   pod_identity_association = [{
    #     role_arn        = module.aws_ebs_csi_pod_identity.iam_role_arn
    #     service_account = "ebs-csi-controller-sa"
    #   }]
    # }


  }

  iam_role_name            = local.stack_name
  iam_role_use_name_prefix = false

  vpc_id                   = var.vpc.vpc_id
  subnet_ids               = var.vpc.private_subnets
  control_plane_subnet_ids = var.vpc.intra_subnets

  create_security_group      = false
  create_node_security_group = false

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
      cidr_blocks = [var.vpc.vpc_cidr]
    }
    vpc_other = {
      description = "Allow all traffic from the VPC to EKS managed workloads 1025-65535"
      type        = "ingress"
      protocol    = "-1"
      from_port   = 1025
      to_port     = 65535
      cidr_blocks = [var.vpc.vpc_cidr]
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
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.2.1"

  name            = "vpc-cni-${local.id}"
  use_name_prefix = false

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
