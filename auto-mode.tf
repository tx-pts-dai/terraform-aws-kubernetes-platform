################################################################################
# EKS Auto Mode - NodePools & NodeClasses
#
# When Auto Mode is enabled, AWS runs a built-in Karpenter. Custom capacity is
# declared with the Auto Mode NodeClass (apiVersion eks.amazonaws.com/v1) and the
# standard Karpenter NodePool (apiVersion karpenter.sh/v1). Both reference the
# node IAM role created by the EKS module (module.eks.node_iam_role_*).
#
# Pass your own resources via var.auto_mode_node_classes / var.auto_mode_node_pools.
# When left empty, a sensible "default" NodeClass + NodePool are created.
################################################################################

locals {
  # Effective subnet-discovery mode for the default NodeClass. Null (the default)
  # resolves to enable_karpenter, so when the self-managed Karpenter stack runs,
  # Auto Mode shares its subnets out of the box; in pure Auto Mode it falls back
  # to the cluster private subnets. coalesce() can't be used here: it treats bool
  # false as empty and would override an explicit `false`.
  discover_karpenter_subnets = var.auto_mode.discover_karpenter_subnets != null ? var.auto_mode.discover_karpenter_subnets : var.enable_karpenter

  # Tags the default NodeClass matches when discovering subnets. Defaults to the
  # tag the module puts on its own dedicated Karpenter subnets; override via
  # var.auto_mode.subnet_discovery_tags to match a customized Karpenter discovery
  # tag (e.g. { "karpenter.sh/discovery" = "shared" }).
  auto_mode_subnet_discovery_tags = var.auto_mode.subnet_discovery_tags != null ? var.auto_mode.subnet_discovery_tags : { "karpenter.sh/discovery" = module.eks.cluster_name }

  # Subnet selector terms for the default NodeClass:
  #   - discover_karpenter_subnets = true: discover by tag (auto_mode_subnet_discovery_tags),
  #     so Auto Mode lands on the SAME subnets as the self-managed Karpenter stack
  #     (the "same network, different NodePools/taints" migration path).
  #   - false: select the cluster private subnets by ID.
  # The two branches differ in both shape (tag vs id) and length, which a plain
  # conditional can't unify; round-tripping through json keeps the ternary a simple
  # string-vs-string and defers the structure to decode time.
  auto_mode_subnet_selector_terms = jsondecode(local.discover_karpenter_subnets ?
    jsonencode([{ tags = local.auto_mode_subnet_discovery_tags }]) :
    jsonencode([for subnet_id in var.vpc.private_subnets : { id = subnet_id }])
  )

  # Default NodeClass using the Auto Mode node IAM role and the cluster primary
  # security group. Named "auto-mode" (not "default") so it never collides with
  # the self-managed karpenter-resources chart's NodePool/EC2NodeClass "default":
  # the NodePool CRD (karpenter.sh/v1) is shared by both controllers, so identical
  # names would fail Helm's ownership check during a coexistence migration.
  default_auto_mode_node_classes = {
    auto-mode = {
      role                       = module.eks.node_iam_role_name
      subnetSelectorTerms        = local.auto_mode_subnet_selector_terms
      securityGroupSelectorTerms = [{ id = module.eks.cluster_primary_security_group_id }]
    }
  }

  # Default NodePool referencing the default NodeClass above. Taints (e.g. for a
  # gradual migration) are added from var.auto_mode.default_node_pool_taints.
  default_auto_mode_node_pools = {
    auto-mode = {
      template = {
        spec = merge({
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "auto-mode"
          }
          requirements = [
            {
              key      = "eks.amazonaws.com/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
          ]
          }, length(var.auto_mode.default_node_pool_taints) > 0 ? {
          taints = [for t in var.auto_mode.default_node_pool_taints : merge(
            { key = t.key, effect = t.effect },
            t.value != null ? { value = t.value } : {}
          )]
        } : {})
      }
      limits = {
        cpu = "1000"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  }

  auto_mode_node_classes = var.enable_auto_mode ? (
    length(var.auto_mode_node_classes) > 0 ? var.auto_mode_node_classes : local.default_auto_mode_node_classes
  ) : {}

  auto_mode_node_pools = var.enable_auto_mode ? (
    length(var.auto_mode_node_pools) > 0 ? var.auto_mode_node_pools : local.default_auto_mode_node_pools
  ) : {}
}

# Authorize the Auto Mode node IAM role to join the cluster. EKS auto-creates this
# access entry only when the cluster's compute_config carries a node_role_arn — i.e.
# when built-in node_pools are requested. We run custom NodePools/NodeClasses, so
# node_role_arn is null on the cluster (see main.tf) and AWS never registers the
# role; without this the NodeClass reports InstanceProfileReady=False /
# "unauthorized to join nodes". Gated on builtin_node_pools being empty so we don't
# collide with the entry AWS creates when built-in pools ARE used. Type "EC2" is the
# Auto Mode node entry; EKS grants node-join permissions for it automatically.
resource "aws_eks_access_entry" "auto_mode_node" {
  count = var.enable_auto_mode && length(var.auto_mode.builtin_node_pools) == 0 ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  type          = "EC2"
}

# The NodeClass/NodePool CRDs only exist after Auto Mode is enabled on the
# cluster, so they are applied via the `custom-resources` Helm chart (which exists
# precisely to work around the Terraform "CRDs not available until apply" catch).
# This also keeps us on the `helm` provider, which defers gracefully on clusters
# created in the same apply — unlike the kubectl provider, which fails at plan.
resource "helm_release" "auto_mode_node_class" {
  for_each = local.auto_mode_node_classes

  name       = "auto-mode-nodeclass-${each.key}"
  chart      = "custom-resources"
  version    = "0.1.3"
  repository = "https://dnd-it.github.io/helm-charts"
  namespace  = local.karpenter.namespace

  # Default the node IAM role to the Auto Mode role created by the EKS module so
  # callers don't need to know its generated name. A `role` set in the passed
  # spec takes precedence.
  values = [yamlencode({
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata = {
      name = each.key
    }
    spec = merge({ role = module.eks.node_iam_role_name }, each.value)
  })]

  depends_on = [module.eks]
}

resource "helm_release" "auto_mode_node_pool" {
  for_each = local.auto_mode_node_pools

  name       = "auto-mode-nodepool-${each.key}"
  chart      = "custom-resources"
  version    = "0.1.3"
  repository = "https://dnd-it.github.io/helm-charts"
  namespace  = local.karpenter.namespace

  values = [yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    spec = each.value
  })]

  depends_on = [helm_release.auto_mode_node_class]
}
