terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/network.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    dynamodb_table       = "terraform-lock"
    region               = "eu-central-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

module "ssm_lookup" {
  source = "../../modules/ssm"

  base_prefix = "infrastructure"
  stack_type  = "network"

  lookup = [
    "public_subnet_ids",
    "vpc_cidr",
    "vpc_id",
    "vpc_name"
  ]

  depends_on = [module.network]

}
