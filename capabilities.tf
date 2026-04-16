################################################################################
# EKS Capabilities
################################################################################

module "ack_capability" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.18.0"

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
