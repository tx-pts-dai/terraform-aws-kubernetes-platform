################################################################################
# EKS Capabilities
################################################################################

data "aws_iam_policy_document" "ack_controller" {
  count = var.enable_ack && var.ack_iam_policy_arn == null ? 1 : 0

  statement {
    sid       = "ACMFull"
    actions   = ["acm:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Route53Full"
    actions   = ["route53:*"]
    resources = ["*"]
  }

  statement {
    sid = "IAMRolePolicyCRUD"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:ListRoles",
      "iam:PutRolePolicy",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EKSPodIdentity"
    actions = [
      "eks:CreatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation",
      "eks:DescribePodIdentityAssociation",
      "eks:ListPodIdentityAssociations",
      "eks:UpdatePodIdentityAssociation",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "IAMPassRole"
    actions   = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["pods.eks.amazonaws.com", "eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ack_controller" {
  count = var.enable_ack && var.ack_iam_policy_arn == null ? 1 : 0

  name        = "ack-controller-${local.id}"
  description = "Least-privilege policy for ACK controllers (ACM, Route53, IAM CRUD, EKS pod identity)"
  policy      = data.aws_iam_policy_document.ack_controller[0].json

  tags = local.tags
}

module "ack_capability" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.15.1"

  create = var.enable_ack

  type         = "ACK"
  cluster_name = module.eks.cluster_name

  iam_role_name            = "ack-${local.id}"
  iam_role_use_name_prefix = false

  iam_role_policies = {
    ack = coalesce(
      var.ack_iam_policy_arn,
      one(aws_iam_policy.ack_controller[*].arn)
    )
  }

  tags = local.tags

  depends_on = [
    time_sleep.wait_after_karpenter
  ]
}
