terraform {
  required_version = "~> 1.10"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/network.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    use_lockfile         = true
    region               = "eu-central-1"
    encrypt              = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9"
    }
  }
}

provider "aws" {
  region = local.region
}

locals {
  region             = "eu-central-1"
  network_stack_name = "ex-network"
}

module "network" {
  source = "../../modules/network"

  stack_name = local.network_stack_name

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
    GithubOrg   = "tx-pts-dai"
  }
}

# Rest of the file is to show how to retrieve the information about the resources created by the "network" module from another stack.
# See the "outputs.tf" file too.
module "ssm_lookup" {
  source = "../../modules/ssm"

  base_prefix = "infrastructure"
  stack_type  = "network"

  lookup = [
    "vpc_cidr",
    "vpc_id",
    "vpc_name"
  ]

  # depends_on can/should be removed if the ssm_lookup is in another stack than the network stack
  depends_on = [module.network]
}

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
