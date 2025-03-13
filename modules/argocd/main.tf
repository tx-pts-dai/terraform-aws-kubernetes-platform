locals {
  # Not recommended to change the namespace as it requires additional configuration
  namespace = "argocd"

  # Module Outputs
  iam_role_arn = try(aws_iam_role.argocd_controller[0].arn, aws_iam_role.spoke[0].arn, null)
  spoke_cluster_secret_yaml = (var.enable_spoke ? <<-EOT
    apiVersion: v1
    kind: Secret
    metadata:
      name: ${var.cluster_name}
      namespace: argocd
      labels:
        argocd.argoproj.io/secret-type: cluster
        ${join("\n", [for k, v in var.labels : "${k}: ${v}"])}
    type: Opaque
    stringData:
      name: ${var.cluster_name}
      server: ${data.aws_eks_cluster.cluster.endpoint}
      config: |
        {
          "tlsClientConfig": {
            "insecure": false,
            "caData": "${data.aws_eks_cluster.cluster.certificate_authority[0].data}"
          },
          "awsAuthConfig": {
            "clusterName": "${var.cluster_name}",
            "roleARN": "${try(aws_iam_role.spoke[0].arn, "")}"
          }
        }
    EOT
  : "")
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

##################### ArgoCD Hub #############################################

data "aws_iam_policy_document" "hub_pod_identity" {
  count = var.enable_hub ? 1 : 0

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
  count = var.enable_hub ? 1 : 0

  name               = "${var.cluster_name}-argocd-controller"
  assume_role_policy = data.aws_iam_policy_document.hub_pod_identity[0].json
}

data "aws_iam_policy_document" "iam_assume_policy" {
  count = var.enable_hub ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_policy" "iam_assume_policy" {
  count = var.enable_hub ? 1 : 0

  name        = "${var.cluster_name}-argocd-aws-assume"
  description = "IAM Policy for ArgoCD Controller"
  policy      = data.aws_iam_policy_document.iam_assume_policy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "iam_assume_policy" {
  count = var.enable_hub ? 1 : 0

  role       = aws_iam_role.argocd_controller[0].name
  policy_arn = aws_iam_policy.iam_assume_policy[0].arn
}

resource "aws_eks_pod_identity_association" "argocd_app_controller" {
  count = var.enable_hub ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = "argocd-application-controller"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "argocd_appset_controller" {
  count = var.enable_hub ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = "argocd-applicationset-controller"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "argocd_api_server" {
  count = var.enable_hub ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = "argocd-server"
  role_arn        = aws_iam_role.argocd_controller[0].arn

  tags = var.tags
}

##################### ArgoCD Spoke ###########################################

data "aws_iam_policy_document" "spoke" {
  count = var.enable_spoke ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [var.hub_iam_role_arn]
    }
  }
}

resource "aws_iam_role" "spoke" {
  count = var.enable_spoke ? 1 : 0

  name               = "${var.cluster_name}-argocd-spoke"
  assume_role_policy = data.aws_iam_policy_document.spoke[0].json

  tags = var.tags
}

resource "aws_eks_access_entry" "example" {
  count = var.enable_spoke ? 1 : 0

  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.spoke[0].arn
  kubernetes_groups = []
  type              = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "example" {
  count = var.enable_spoke ? 1 : 0

  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.spoke[0].arn

  access_scope {
    type = "cluster"
  }
}
##################### ArgoCD Helm Chart ######################################

module "argocd" {
  source = "../addon"

  create = var.enable_hub || var.enable_spoke

  chart         = "argo-cd"
  chart_version = "7.8.10"
  repository    = "https://argoproj.github.io/argo-helm"
  description   = "A Helm chart to install the ArgoCD"
  namespace     = local.namespace

  create_namespace = true

  # https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml
  values = var.values
  set    = var.set

  tags = var.tags
}
