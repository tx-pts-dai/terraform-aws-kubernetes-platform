################################################################################
# EKS Auto Mode - NodePools & NodeClasses
#
# When Auto Mode is enabled, AWS runs a built-in Karpenter. Custom capacity is
# declared with the Auto Mode NodeClass (apiVersion eks.amazonaws.com/v1) and the
# standard Karpenter NodePool (apiVersion karpenter.sh/v1).
#
# Pass your own resources via var.auto_mode_node_classes / var.auto_mode_node_pools.
# When left empty, a sensible "default" NodeClass + NodePool are created.
################################################################################

locals {
  # Null (the default) resolves to enable_karpenter, so Auto Mode shares the
  # self-managed Karpenter subnets when that stack is running, falling back to the
  # cluster private subnets in pure Auto Mode. Not coalesce(): it treats `false` as
  # empty and would override an explicit false.
  discover_karpenter_subnets = var.auto_mode.discover_karpenter_subnets != null ? var.auto_mode.discover_karpenter_subnets : var.enable_karpenter

  # Defaults to the tag the module puts on its own dedicated Karpenter subnets;
  # override via var.auto_mode.subnet_discovery_tags for a customized tag.
  auto_mode_subnet_discovery_tags = var.auto_mode.subnet_discovery_tags != null ? var.auto_mode.subnet_discovery_tags : { "karpenter.sh/discovery" = module.eks.cluster_name }

  # discover_karpenter_subnets true -> discover by tag (same subnets as
  # self-managed Karpenter); false -> select var.vpc.private_subnets by ID. The two
  # shapes can't unify in a plain conditional, so the ternary stays string-vs-string
  # and jsondecode restores the structure.
  auto_mode_subnet_selector_terms = jsondecode(local.discover_karpenter_subnets ?
    jsonencode([{ tags = local.auto_mode_subnet_discovery_tags }]) :
    jsonencode([for subnet_id in var.vpc.private_subnets : { id = subnet_id }])
  )

  # Named "auto-mode", not "default": the karpenter.sh/v1 NodePool CRD is shared by
  # both controllers, so reusing the self-managed stack's "default" name would fail
  # Helm's ownership check during coexistence.
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

# EKS only auto-creates this access entry when compute_config carries a
# node_role_arn (i.e. built-in node_pools are requested). We run custom
# NodePools/NodeClasses instead, so node_role_arn is null and AWS never registers
# the role — without this the NodeClass reports InstanceProfileReady=False. Gated
# on builtin_node_pools being empty to avoid colliding with AWS's own entry when
# built-in pools are used.
resource "aws_eks_access_entry" "auto_mode_node" {
  count = var.enable_auto_mode && length(var.auto_mode.builtin_node_pools) == 0 ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  type          = "EC2"
}

# Applied via the `custom-resources` Helm chart since the NodeClass/NodePool CRDs
# only exist after Auto Mode is enabled — the `helm` provider defers gracefully on
# clusters created in the same apply, unlike `kubectl`, which fails at plan.
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
