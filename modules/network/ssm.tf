module "ssm" {
  count = var.create_vpc ? 1 : 0

  source = "./../ssm"

  stack_type = "network"
  stack_name = var.stack_name

  parameters = {
    vpc_cidr = {
      insecure_value = module.vpc.vpc_cidr_block
    },
    vpc_id = {
      insecure_value = module.vpc.vpc_id
    }
  }

  tags = var.tags
}
