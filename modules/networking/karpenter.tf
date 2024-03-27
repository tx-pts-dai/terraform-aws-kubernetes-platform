locals {
  # Not the place for this info but will store here for now
  # cidrsubnet(prefix, newbits, netnum)
  # cidrsubnet("10.0.0.0/16", 4, 4) => 10.0.64.0/20
  # newbits /16 + 4 = /20
  # netnum /16 has 16 /20 networks, netnum 4 is the 5th /20 network
  # /24 256 addresses
  # /23 512 addresses
  # /22 1024 addresses
  # /21 2048 addresses
  # /20 4096 addresses

  karpenter = {
    subnet_newbits = 6
    subnet_netnum = 4
  }
  vpc_id = try(var.karpenter.vpc_id, module.vpc.vpc_id)

  vpc_additional_cidr_private_subnets = [for k, _ in local.azs : cidrsubnet(var.cidr, local.karpenter.subnet_newbits, k + local.karpenter.subnet_netnum)]
}

resource "aws_subnet" "karpenter" {
  count = length(local.vpc_additional_cidr_private_subnets)

  vpc_id            = local.vpc_id
  cidr_block        = local.vpc_additional_cidr_private_subnets[count.index]
  availability_zone = element(local.azs, count.index)
  tags = {
    Name                     = "${var.name}-karpenter-${element(local.azs, count.index)}"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

data "aws_route_tables" "private_route_tables" {
  vpc_id = local.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

resource "aws_route_table_association" "private" {
  count = length(local.vpc_additional_cidr_private_subnets)

  subnet_id      = aws_subnet.karpenter[count.index].id
  route_table_id = try(data.aws_route_tables.private_route_tables.ids[count.index], data.aws_route_tables.private_route_tables.ids[0]) # if there is only one route table, use it
}