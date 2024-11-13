output "network_stack_infos" {
  description = "Example of how to retrieve infos from network module from another stack"
  value = {
    public_subnet_ids = data.aws_subnets.public_subnets.ids
    vpc_cidr          = module.ssm_lookup.lookup[local.network_stack_name].vpc_cidr
    vpc_id            = module.ssm_lookup.lookup[local.network_stack_name].vpc_id
    vpc_name          = module.ssm_lookup.lookup[local.network_stack_name].vpc_name
  }
}
