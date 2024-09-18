module "ssm" {
  source = "./modules/ssm"

  create = var.create_core

  stack_type = "platform"
  stack_name = local.stack_name

  parameters = {
    cluster_name = {
      insecure_value = module.eks.cluster_name
    },
    cluster_endpoint = {
      insecure_value = module.eks.cluster_endpoint
    },
    cluster_arn = {
      insecure_value = module.eks.cluster_arn
    },
    cluster_certificate_authority_data = {
      insecure_value = base64encode(module.eks.cluster_certificate_authority_data)
    },
  }

  tags = local.tags
}
