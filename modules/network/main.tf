data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

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
  version = "6.4.0"

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
    "karpenter.sh/discovery"          = "shared"
  }

  tags = var.tags
}

###################### VPC Endpoints ######################
resource "aws_security_group" "vpc_endpoints" {
  count = var.create_vpc_endpoints ? 1 : 0

  name        = "${var.stack_name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.stack_name}-vpc-endpoints"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = var.enabled_vpc_endpoints_private_dns

  tags = merge(
    var.tags,
    {
      Name = "${var.stack_name}-ecr-api"
    }
  )
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = var.enabled_vpc_endpoints_private_dns

  tags = merge(
    var.tags,
    {
      Name = "${var.stack_name}-ecr-dkr"
    }
  )
}

resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "*"
        Resource  = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.stack_name}-s3"
    }
  )
}
