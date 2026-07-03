################################################################################
# TAMEDIA KUBERNETES AS A SERVICE (TKaaS)
#
# Batteries included Kubernetes clusters.
#
# main.tf
# This file is the entrypoint for the TKaaS module. It is responsible for
# orchestrating the creation of the Kubernetes cluster.
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
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  cluster_admin_arns = { for k, v in var.cluster_admins : k => {
    role_arn          = v.role_arn != null ? v.role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${v.role_name}"
    kubernetes_groups = v.kubernetes_groups
  } }

  sso_admin_arns = var.enable_sso_admin_auto_discovery ? try(tolist(data.aws_iam_roles.sso[0].arns), []) : []

  sso_admin = length(local.sso_admin_arns) == 1 ? {
    sso_admin = {
      role_arn          = local.sso_admin_arns[0]
      kubernetes_groups = null
    }
  } : {}

  all_admins = merge(local.sso_admin, local.cluster_admin_arns)

  access_entries = { for k, v in local.all_admins : k => {
    principal_arn     = v.role_arn
    type              = "STANDARD"
    kubernetes_groups = v.kubernetes_groups

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

################################################################################
# Core Addon Configuration
locals {
  # Default vpc-cni configuration
  vpc_cni_default_config = {
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
    }
  }

  # Merge user-provided vpc-cni configuration with defaults (deep merge for env)
  vpc_cni_user_config = try(jsondecode(var.eks.vpc_cni.configuration_values), {})
  vpc_cni_merged_config = jsonencode(merge(
    local.vpc_cni_default_config,
    local.vpc_cni_user_config,
    contains(keys(local.vpc_cni_user_config), "env") ? {
      env = merge(
        local.vpc_cni_default_config.env,
        local.vpc_cni_user_config.env
      )
    } : {}
  ))
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name                    = local.stack_name
  kubernetes_version      = var.kubernetes_version
  endpoint_public_access  = try(var.eks.cluster_endpoint_public_access, true)
  endpoint_private_access = try(var.eks.cluster_endpoint_private_access, true)

  # Configurable for brownfield adoption. Default "API" (greenfield). When adopting a
  # cluster on the legacy aws-auth ConfigMap, set "API_AND_CONFIG_MAP" so both auth
  # paths stay live while access entries are created and verified — going straight to
  # "API" drops the ConfigMap, cutting off every principal not yet an access entry.
  authentication_mode = try(var.eks.authentication_mode, "API")

  # EKS Auto Mode. When enabled, AWS manages compute, storage, load balancing and
  # core networking. The networking / Pod Identity addons below are suppressed only
  # in PURE Auto Mode (no self-managed Karpenter); they are retained while
  # enable_karpenter is true so the self-managed nodes get pod networking (see
  # local.create_self_managed_networking). Storage and load balancing have their own
  # self-managed toggles (enable_self_managed_ebs_csi / enable_self_managed_lb_controller)
  # so they can be migrated independently.
  create_auto_mode_iam_resources    = var.enable_auto_mode
  node_iam_role_additional_policies = var.auto_mode.node_iam_role_additional_policies

  # node_pools must be null (not []) when no AWS built-in pools are requested: the
  # EKS module derives the cluster-level node_role_arn from `node_pools != null`,
  # and AWS rejects a non-empty nodeRoleArn with an empty nodePool list
  # ("When nodeRoleArn is not null or empty, nodePool value(s) must be provided").
  # Passing null means "bring your own NodePool/NodeClass" — our custom NodeClass
  # carries its own role.
  compute_config = var.enable_auto_mode ? {
    enabled    = true
    node_pools = length(var.auto_mode.builtin_node_pools) > 0 ? var.auto_mode.builtin_node_pools : null
  } : null

  # Networking (VPC CNI, kube-proxy) and the Pod Identity agent run as node-level
  # services on Auto Mode nodes; Auto Mode does NOT extend them to non-Auto-Mode
  # nodes. While the self-managed Karpenter stack runs (enable_karpenter), its nodes
  # are ordinary EC2 nodes that need the traditional vpc-cni / kube-proxy DaemonSets
  # (and the Pod Identity agent) to get pod networking and become Ready — so these
  # are retained via local.create_self_managed_networking and dropped only in PURE
  # Auto Mode. Mirrors the CoreDNS rule in addons.tf.
  #
  # Each addon is gated individually via merge(): a single `... ? {...} : {}` over
  # all three at once fails type-checking, because the addons have different
  # attribute sets and an empty object can't unify with them as a map.
  addons = merge(
    local.create_self_managed_networking ? {
      vpc-cni = {
        before_compute = true

        most_recent = true
        preserve    = true

        # This addon sets preserve = true, so its aws-node resources stay on the
        # cluster after the addon is removed — e.g. while suppressed under Auto Mode.
        # Re-creating the addon must adopt those leftover resources; without OVERWRITE
        # the create fails with ConfigurationConflict on their version labels. No-op
        # on a clean cluster.
        resolve_conflicts_on_create = "OVERWRITE"

        service_account_role_arn = module.vpc_cni_irsa.arn

        # TODO: https://github.com/hashicorp/terraform-provider-aws/issues/30645
        # pod_identity_association = [
        #   {
        #     role_arn        = module.aws_vpc_cni_pod_identity.iam_role_arn
        #     service_account = "aws-node"
        #   }
        # ]

        configuration_values = local.vpc_cni_merged_config
      }
    } : {},

    local.create_self_managed_networking ? {
      kube-proxy = {
        before_compute = true

        most_recent = true
        preserve    = true

        # See vpc-cni above: adopt existing resources rather than fail on conflict.
        resolve_conflicts_on_create = "OVERWRITE"

        configuration_values = try(var.eks.kube_proxy.configuration_values, null)
      }
    } : {},

    local.create_self_managed_networking ? {
      eks-pod-identity-agent = {
        before_compute = true

        most_recent = true
        preserve    = true

        # See vpc-cni above: adopt existing resources rather than fail on conflict.
        resolve_conflicts_on_create = "OVERWRITE"

        configuration_values = try(var.eks.eks_pod_identity_agent.configuration_values, null)

        timeouts = {
          create = "3m"
          delete = "3m"
        }
      }
    } : {},
  )

  create_iam_role          = try(var.eks.create_iam_role, true)
  iam_role_arn             = try(var.eks.iam_role_arn, null)
  iam_role_name            = local.stack_name
  iam_role_use_name_prefix = false

  # Encryption / KMS — exposed for brownfield adoption. Defaults preserve the eks
  # module behaviour (create a KMS key + encrypt secrets). To adopt a cluster that
  # has NO encryption today, set var.eks.encryption_config = null and
  # var.eks.create_kms_key = false: enabling secrets encryption is IRREVERSIBLE, so
  # it must be an explicit choice, not a side effect of adoption.
  encryption_config = try(var.eks.encryption_config, {})
  create_kms_key    = try(var.eks.create_kms_key, true)

  vpc_id                   = var.vpc.vpc_id
  subnet_ids               = var.vpc.private_subnets
  control_plane_subnet_ids = var.vpc.intra_subnets

  create_security_group      = false
  create_node_security_group = false

  enable_cluster_creator_admin_permissions = try(var.eks.enable_cluster_creator_admin_permissions, false)

  # Fargate is only needed to host the self-managed Karpenter controller, so it
  # follows enable_karpenter (not Auto Mode) to support running both side-by-side.
  fargate_profiles = var.enable_karpenter ? {
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
  } : {}

  # Admin entries last so they win on any key collision.
  access_entries = merge(var.access_entries, local.access_entries)

  tags = local.tags
}

# Allows all traffic from the VPC to the EKS control plane
locals {
  ingress_rules = {
    vpc_control_plane = {
      description = "Allow all traffic from the VPC to EKS managed workloads over HTTPS"
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
module "aws_vpc_cni_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

  create = local.create_self_managed_networking

  name                    = "aws-vpc-cni-pod-identity-${local.id}"
  aws_vpc_cni_policy_name = "aws-vpc-cni-pod-identity-${local.id}"
  use_name_prefix         = false

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true
  aws_vpc_cni_enable_ipv6   = true

  tags = local.tags
}


module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  create = local.create_self_managed_networking

  name            = "vpc-cni-${local.id}"
  policy_name     = "vpc-cni-${local.id}"
  use_name_prefix = false

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  vpc_cni_enable_ipv6   = true

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
  destroy_duration = "1m"
}
