module "ssm" {
  source = "./modules/ssm"

  stack_type = "platform"
  stack_name = local.stack_name

  parameters = {
    cluster_name = {
      insecure_value = module.eks.cluster_name
    }
  }

  tags = local.tags
}
