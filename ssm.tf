module "ssm_platform" {
  source = "./modules/ssm"

  latest = var.ssm_latest

  stack_type = "platform"
  stack_name = local.stack_name
  parameters = {
    cluster_name = {
      name  = "cluster_name"
      value = module.eks.cluster_name
    },
    cluster_endpoint = {
      name  = "cluster_endpoint"
      value = module.eks.cluster_endpoint
    },
    cluster_arn = {
      name  = "cluster_arn"
      value = module.eks.cluster_arn
    },
    cluster_certificate_authority_data = {
      name  = "cluster-certificate-authority-data"
      value = base64encode(module.eks.cluster_certificate_authority_data)
    },
  }

  tags = local.tags
}
