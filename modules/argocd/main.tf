locals {
  # Module Outputs
  iam_role_arn = try(aws_iam_role.argocd_controller[0].arn, aws_iam_role.argocd_spoke[0].arn, null)

  full_cluster_name = join("-", [var.cluster_name, var.cluster_secret_suffix])

  cluster_secret_yaml = <<-EOT
    apiVersion: v1
    kind: Secret
    metadata:
      name: cluster-${local.full_cluster_name}
      namespace: ${var.namespace}
      labels:
        argocd.argoproj.io/secret-type: cluster
        ${join("\n    ", [for k, v in var.cluster_secret_labels : "${k}: ${v}"])}
    type: "Opaque"
    stringData:
      name: ${local.full_cluster_name}
      server: ${data.aws_eks_cluster.cluster.endpoint}
      config: |
        {
          "tlsClientConfig": {
            "insecure": false,
            "caData": "${data.aws_eks_cluster.cluster.certificate_authority[0].data}"
          },
          "awsAuthConfig": {
            "clusterName": "${var.cluster_name}",
            "roleARN": "${local.iam_role_arn}"
          }
        }
  EOT
}

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

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "argocd-application-controller"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "argocd_applicationset_controller" {
  count = var.create && var.enable_hub ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "argocd-applicationset-controller"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "argocd_server" {
  count = var.create && var.enable_hub ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "argocd-server"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

##################### ArgoCD Spoke ###########################################
locals {
  hub_iam_role_arn = var.create && var.enable_spoke ? (var.hub_iam_role_arn != null ? var.hub_iam_role_arn : (var.enable_hub ? aws_iam_role.argocd_controller[0].arn : null)) : null
}

data "aws_iam_policy_document" "argocd_spoke" {
  count = var.create && var.enable_spoke ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [local.hub_iam_role_arn]
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

  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.argocd_spoke[0].arn
  kubernetes_groups = []
  type              = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "argocd_spoke" {
  count = var.create && var.enable_spoke ? 1 : 0

  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.argocd_spoke[0].arn

  access_scope {
    type = "cluster"
  }
}
##################### ArgoCD Helm Chart ######################################

module "argocd" {
  source = "../addon"

  create = var.create && (var.enable_hub || var.enable_spoke)

  chart         = "argo-cd"
  chart_version = "7.8.10"
  repository    = "https://argoproj.github.io/argo-helm"
  description   = "A Helm chart to install the ArgoCD"
  namespace     = var.namespace
  wait          = true

  create_namespace = true

  # https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml
  values = var.helm_values
  set    = var.helm_set

  tags = var.tags
}
