module "ssm" {
  source = "./modules/ssm"

  stack_type = "platform"
  stack_name = local.stack_name

  parameters = merge(
    {
      cluster_name = {
        insecure_value = module.eks.cluster_name
      }
    },
    var.enable_s3files_storage ? {
      s3files_file_system_id = {
        insecure_value = aws_s3files_file_system.this[0].id
      }
    } : {},
  )

  tags = local.tags
}
