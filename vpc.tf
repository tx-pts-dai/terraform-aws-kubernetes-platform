data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                          = "vpc_${var.environment}"
  cidr                          = var.cidr
  azs                           = data.aws_availability_zones.available.names
  private_subnets               = var.private_subnets
  public_subnets                = var.public_subnets
  enable_nat_gateway            = true
  single_nat_gateway            = true
  manage_default_network_acl    = false # Default changed from false to true with v4.0 of the module (https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/UPGRADE-4.0.md#modified)
  manage_default_route_table    = false # Default changed from false to true with v4.0 of the module (https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/UPGRADE-4.0.md#modified)
  manage_default_security_group = false # Default changed from false to true with v4.0 of the module (https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/UPGRADE-4.0.md#modified)
  map_public_ip_on_launch       = true  # Default changed from true to false with v4.0 of the module (https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/UPGRADE-4.0.md#modified)


  tags = {
    Terraform   = "true"
    Environment = var.environment
    Name        = "${var.cluster_name}-vpc"
  }

  public_subnet_tags = {
    Name = "${var.cluster_name}-public"

    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "Name"                            = "${var.cluster_name}-private"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }
}
