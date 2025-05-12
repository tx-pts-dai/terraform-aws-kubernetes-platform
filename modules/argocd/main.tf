data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

##################### ArgoCD Hub #############################################

data "aws_iam_policy_document" "argocd_controller_assume_role" {
  count = var.create && var.enable_hub ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "argocd_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  name               = var.hub_iam_role_name
  assume_role_policy = data.aws_iam_policy_document.argocd_controller_assume_role[0].json
}

data "aws_iam_policy_document" "argocd_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_policy" "argocd_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  name        = "${var.cluster_name}-argocd-aws-assume"
  description = "IAM Policy for ArgoCD Controller"
  policy      = data.aws_iam_policy_document.argocd_controller[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "argocd_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  role       = aws_iam_role.argocd_controller[0].name
  policy_arn = aws_iam_policy.argocd_controller[0].arn
}

resource "aws_eks_pod_identity_association" "argocd_application_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  cluster_name    = data.aws_eks_cluster.cluster.name
  namespace       = var.namespace
  service_account = "argocd-application-controller"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "argocd_applicationset_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  cluster_name    = data.aws_eks_cluster.cluster.name
  namespace       = var.namespace
  service_account = "argocd-applicationset-controller"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "argocd_server" {
  count = var.create && var.enable_hub ? 1 : 0

  cluster_name    = data.aws_eks_cluster.cluster.name
  namespace       = var.namespace
  service_account = "argocd-server"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "helm_release" "argocd" {
  count = var.create && var.enable_hub ? 1 : 0

  name             = "argocd"
  description      = "A Helm chart to install the ArgoCD"
  chart            = "argo-cd"
  version          = var.helm_version
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = var.namespace
  wait             = true
  create_namespace = true

  # https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml
  values = var.helm_values

  dynamic "set" {
    for_each = var.helm_set

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  depends_on = [
    aws_iam_role.argocd_controller
  ]
}

##################### ArgoCD Spoke ###########################################
locals {
  # Remove this when the variable hub_iam_role_arn is deprecated
  hub_iam_role_arn_list = distinct(flatten([
    var.hub_iam_role_arns != null ? var.hub_iam_role_arns : [],
    var.hub_iam_role_arn != null ? [var.hub_iam_role_arn] : []
  ]))

  hub_iam_role_arns = var.create && var.enable_spoke ? (
    length(local.hub_iam_role_arn_list) > 0 ? local.hub_iam_role_arn_list : (
      var.enable_hub ? [aws_iam_role.argocd_controller[0].arn] : []
    )
  ) : []
}

data "aws_iam_policy_document" "argocd_spoke" {
  count = var.create && var.enable_spoke ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = local.hub_iam_role_arns
    }
  }
}

resource "aws_iam_role" "argocd_spoke" {
  count = var.create && var.enable_spoke ? 1 : 0

  name               = "${var.cluster_name}-argocd-spoke"
  assume_role_policy = data.aws_iam_policy_document.argocd_spoke[0].json

  tags = var.tags
}

resource "aws_eks_access_entry" "argocd_spoke" {
  count = var.create && var.enable_spoke ? 1 : 0

  cluster_name      = data.aws_eks_cluster.cluster.name
  principal_arn     = aws_iam_role.argocd_spoke[0].arn
  kubernetes_groups = []
  type              = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "argocd_spoke" {
  count = var.create && var.enable_spoke ? 1 : 0

  cluster_name  = data.aws_eks_cluster.cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.argocd_spoke[0].arn

  access_scope {
    type = "cluster"
  }
}
##################### ArgoCD Helm Chart ######################################
