data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  subnet_list = flatten([
    for subnet_map in var.subnet_configs : [
      for subnet_name, size in subnet_map : [
        for az in local.azs : {
          name     = subnet_name,
          az       = az,
          new_bits = size - tonumber(split("/", var.cidr)[1])
          hosts    = pow(2, 32 - size) - 4 # 2 reserved, 1 network, 1 broadcast
        }
      ]
    ]
  ])

  network_by_index = cidrsubnets(var.cidr, local.subnet_list[*].new_bits...)

  network_by_name = { for i, n in local.subnet_list : "${n.name}-${n.az}" => local.network_by_index[i] if n.name != null }

  networks = [for i, n in local.subnet_list : {
    name       = n.name
    az         = n.az
    hosts      = n.hosts
    cidr_block = n.name != null ? local.network_by_index[i] : tostring(null)
  }]

  grouped_networks = {
    for net in local.networks : net.name => net.cidr_block...
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  create_vpc = var.create_vpc

  name = var.stack_name
  cidr = var.cidr

  azs = local.azs

  public_subnets      = [for k, v in local.networks : v.cidr_block if v.name == "public"]
  private_subnets     = [for k, v in local.networks : v.cidr_block if v.name == "private"]
  intra_subnets       = [for k, v in local.networks : v.cidr_block if v.name == "intra"]
  database_subnets    = [for k, v in local.networks : v.cidr_block if v.name == "database"]
  redshift_subnets    = [for k, v in local.networks : v.cidr_block if v.name == "redshift"]
  elasticache_subnets = [for k, v in local.networks : v.cidr_block if v.name == "elasticache"]

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}
