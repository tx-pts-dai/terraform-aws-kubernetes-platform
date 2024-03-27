# Deploy the SecretsManager operator so that the app can get secrets runtime from K8s via the app-helm-chart
module "eks_addons_secretstore" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_external_secrets = true
}

resource "kubectl_manifest" "secretsmanager_auth" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
        name: aws-secretsmanager
    spec:
        provider:
            aws:
                service: SecretsManager
                region: ${data.aws_region.current.name}
  YAML
}
