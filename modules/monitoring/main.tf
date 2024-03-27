locals {
  tags = var.tags
}

module "fluent_operator" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  chart            = "fluent-operator"
  chart_version    = "2.7.0"
  repository       = "https://fluent.github.io/helm-charts/"
  description      = "Fluent Operator Helm Chart"
  namespace        = "monitoring"
  create_namespace = true

  set = [
    {
      name  = "containerRuntime"
      value = "containerd"
    },
    {
      name  = "fluentd.crdsEnable"
      value = false
    }
  ]

  set_irsa_names = ["serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"]
  # # Equivalent to the following but the ARN is only known internally to the module
  # set = [{
  #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  #   value = iam_role_arn.this[0].arn
  # }]

  # IAM role for service account (IRSA)
  create_role = true
  role_name   = "fluent-operator"
  role_policies = {
    fluent-operator = "arn:aws:iam::111111111111:policy/CREATEPOLICY"
  }

  oidc_providers = {
    this = {
      provider_arn = var.fluent_operator.oidc_provider_arn
      # namespace is inherited from chart
      service_account = "fluent-operator"
    }
  }

  tags = local.tags
}