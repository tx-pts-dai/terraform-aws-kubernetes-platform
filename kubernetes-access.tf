################################################################################
# Kubernetes Access Roles
# Creates reusable standard roles that can be assumed by multiple principals
# Supports different access levels: view, edit, admin, and custom
################################################################################

locals {
  kubernetes_access_roles = var.kubernetes_access_roles

  # Map access levels to AWS managed EKS policies
  access_level_policy_map = {
    view  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    edit  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
    admin = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  }

  # Flatten custom policy associations for iteration
  custom_policy_associations = flatten([
    for role_key, role_config in local.kubernetes_access_roles : [
      for policy_arn in(role_config.access_level == "custom" ? role_config.custom_policy_arns : []) : {
        role_key   = role_key
        policy_arn = policy_arn
        scope      = role_config.scope
        namespaces = role_config.namespaces
      }
    ]
  ])
}

# Standard reusable IAM roles (e.g., readonly, developer, ops-admin)
resource "aws_iam_role" "k8s_access" {
  for_each = local.kubernetes_access_roles

  name               = "${local.stack_name}-k8s-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.k8s_access_assume[each.key].json

  tags = merge(
    local.tags,
    {
      Name        = "${local.stack_name}-k8s-${each.key}"
      Purpose     = "Reusable Kubernetes access role"
      AccessLevel = each.value.access_level
      Scope       = each.value.scope
    }
  )
}

# Trust policy allowing multiple controller IAM roles to assume each standard role
data "aws_iam_policy_document" "k8s_access_assume" {
  for_each = local.kubernetes_access_roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = each.value.controller_iam_role_arns
    }

    # Optional: Add external ID for additional security
    dynamic "condition" {
      for_each = lookup(each.value, "external_id", null) != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [each.value.external_id]
      }
    }
  }
}

# EKS Access Entry - grants the IAM role access to the Kubernetes API
resource "aws_eks_access_entry" "k8s_access" {
  for_each = local.kubernetes_access_roles

  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_role.k8s_access[each.key].arn
  kubernetes_groups = []
  type              = "STANDARD"

  tags = merge(
    local.tags,
    {
      Name        = "${local.stack_name}-k8s-${each.key}"
      Purpose     = "EKS access for ${each.key} role"
      AccessLevel = each.value.access_level
    }
  )

  depends_on = [
    module.eks
  ]
}

# EKS Access Policy Association - grants permissions based on access level (view/edit/admin)
resource "aws_eks_access_policy_association" "k8s_access_predefined" {
  for_each = {
    for k, v in local.kubernetes_access_roles : k => v
    if v.access_level != "custom"
  }

  cluster_name  = module.eks.cluster_name
  policy_arn    = local.access_level_policy_map[each.value.access_level]
  principal_arn = aws_iam_role.k8s_access[each.key].arn

  access_scope {
    type       = each.value.scope
    namespaces = each.value.scope == "namespace" ? each.value.namespaces : []
  }

  depends_on = [
    aws_eks_access_entry.k8s_access
  ]
}

# EKS Access Policy Association - grants custom permissions
resource "aws_eks_access_policy_association" "k8s_access_custom" {
  for_each = {
    for idx, item in local.custom_policy_associations : "${item.role_key}-${idx}" => item
  }

  cluster_name  = module.eks.cluster_name
  policy_arn    = each.value.policy_arn
  principal_arn = aws_iam_role.k8s_access[each.value.role_key].arn

  access_scope {
    type       = each.value.scope
    namespaces = each.value.scope == "namespace" ? each.value.namespaces : []
  }

  depends_on = [
    aws_eks_access_entry.k8s_access
  ]
}
