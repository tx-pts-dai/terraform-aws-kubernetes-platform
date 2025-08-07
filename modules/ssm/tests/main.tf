terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "ssm/tests/terraform.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    use_lockfile         = true
    region               = "eu-central-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  region = "eu-central-1"
}

provider "aws" {
  region = local.region
}

module "ssm_lookup_latest_stack_parameters" {
  source = "./.."

  base_prefix       = "infrastructure"
  stack_type        = "platform"
  stack_name_prefix = ""
}
