data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [module.ssm_lookup.lookup[local.network_stack_name].vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}
