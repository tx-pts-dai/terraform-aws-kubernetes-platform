################################################################################
# EKS Capabilities
################################################################################

module "ack_capability" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.24.0"

  create = var.enable_ack

  type         = "ACK"
  cluster_name = module.eks.cluster_name

  iam_role_name            = "ack-${local.id}"
  iam_role_use_name_prefix = false

  iam_role_policies = {
    ack = coalesce(var.ack_iam_policy_arn, "arn:aws:iam::aws:policy/AdministratorAccess")
  }

  tags = local.tags

  depends_on = [
    time_sleep.wait_after_karpenter
  ]
}

################################################################################
# Argo CD (AWS-managed EKS capability)
#
# The managed Argo CD server requires IAM Identity Center for authentication. The
# instance ARN is taken from var.argocd_capability.idc_instance_arn, or
# auto-discovered from the account/org Identity Center instance. Argo CD is
# publicly accessible unless argocd_capability.vpce_ids is set.
data "aws_ssoadmin_instances" "this" {
  count = var.enable_argocd_capability && var.argocd_capability.idc_instance_arn == null ? 1 : 0
}

locals {
  argocd_idc_instance_arn = var.enable_argocd_capability ? (
    var.argocd_capability.idc_instance_arn != null
    ? var.argocd_capability.idc_instance_arn
    : try(data.aws_ssoadmin_instances.this[0].arns[0], null)
  ) : null
}

check "argocd_capability_idc" {
  assert {
    condition     = !var.enable_argocd_capability || local.argocd_idc_instance_arn != null
    error_message = "enable_argocd_capability is true but no IAM Identity Center instance ARN could be resolved. Set argocd_capability.idc_instance_arn, or ensure an Identity Center instance exists and the apply role has sso:ListInstances."
  }
}

module "argocd_capability" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.15.1"

  create = var.enable_argocd_capability

  type         = "ARGOCD"
  cluster_name = module.eks.cluster_name

  iam_role_name            = "argocd-${local.id}"
  iam_role_use_name_prefix = false

  configuration = {
    argo_cd = {
      aws_idc = {
        idc_instance_arn = local.argocd_idc_instance_arn
        idc_region       = var.argocd_capability.idc_region
      }
      namespace         = var.argocd_capability.namespace
      rbac_role_mapping = length(var.argocd_capability.rbac_role_mapping) > 0 ? var.argocd_capability.rbac_role_mapping : null
      # Public endpoint unless VPC endpoints are provided (setting vpce_ids blocks public access).
      network_access = length(var.argocd_capability.vpce_ids) > 0 ? { vpce_ids = var.argocd_capability.vpce_ids } : null
    }
  }

  iam_policy_statements = length(var.argocd_capability.iam_policy_statements) > 0 ? var.argocd_capability.iam_policy_statements : null

  tags = local.tags

  depends_on = [
    module.eks
  ]
}
