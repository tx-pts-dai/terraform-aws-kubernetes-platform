data "aws_availability_zones" "available" {}

locals {
    azs = slice(data.aws_availability_zones.available.names, 0, var.max_azs)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.0"

  create_vpc = var.create_vpc

  name = var.name
  cidr = var.cidr

  azs = local.azs

  public_subnets   = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k)]
  intra_subnets    = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k + 8)]
  database_subnets = [for k, _ in local.azs : cidrsubnet(var.cidr, 8, k + 16)]
  # ...
  # keep private at the end since they are the most likely to change/expand
  private_subnets = [for k, v in local.azs : cidrsubnet(var.cidr, 6, k + 4)]

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = var.tags
}

