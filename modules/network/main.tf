data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.0"

  create_vpc = var.create_vpc

  name = var.stack_name
  cidr = var.cidr

  azs = local.azs

  public_subnets   = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k)]
  intra_subnets    = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k + 3)]
  database_subnets = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k + 6)]
  private_subnets  = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k + 9)]

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
