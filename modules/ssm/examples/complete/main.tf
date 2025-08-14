terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "ssm/examples/complete.tfstate"
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
  region = "us-east-2"
}

provider "aws" {
  region = local.region
}

module "ssm_store_one" {
  source = "./../.."

  base_prefix = "infrastructure"
  stack_type  = "platform"
  stack_name  = "stack-123"

  parameters = {
    cluster_endpoint = {
      name           = "cluster_endpoint"
      insecure_value = "cluster-zxcv"
    }
    cluster_name = {
      value = "foo"
    }
  }
}

module "ssm_store_two" {
  source = "./../.."

  base_prefix = "infrastructure"
  stack_type  = "platform"
  stack_name  = "stack-234"

  parameters = {
    cluster_endpoint = {
      name           = "cluster_endpoint"
      insecure_value = "cluster-asjf"
    }
    cluster_name = {
      value = "bar"
    }
  }
}

module "ssm_store_three" {
  source = "./../.."

  base_prefix = "infrastructure"
  stack_type  = "network"
  stack_name  = "stack-234"

  parameters = {
    vpc_id = {
      name           = "vpc_id"
      insecure_value = "vpc-234"
    }
    vpc_cidr = {
      value = "10.2.0.0/16"
    }
  }
}

module "ssm_lookup_type" {
  source = "./../.."

  base_prefix       = "infrastructure"
  stack_type        = "platform"
  stack_name_prefix = "stack"

  lookup = ["cluster_name", "cluster_endpoint"]

  depends_on = [
    module.ssm_store_one,
    module.ssm_store_two
  ]
}

module "ssm_lookup_all" {
  source = "./../.."

  base_prefix       = "infrastructure"
  stack_type        = ""
  stack_name_prefix = ""

  lookup = ["vpc_id", "cluster_name", "cluster_endpoint"]

  depends_on = [
    module.ssm_store_one,
    module.ssm_store_two
  ]
}

module "ssm_lookup_single" {
  source = "./../.."

  base_prefix       = "infrastructure"
  stack_type        = "platform"
  stack_name_prefix = "stack-123"

  lookup = ["vpc_id", "cluster_name", "cluster_endpoint"]

  depends_on = [
    module.ssm_store_one,
    module.ssm_store_two
  ]
}

module "ssm_lookup_match" {
  source = "./../.."

  base_prefix       = "infrastructure"
  stack_type        = ""
  stack_name_prefix = "stack-234"

  lookup = ["vpc_id", "cluster_name", "cluster_endpoint"]

  depends_on = [
    module.ssm_store_one,
    module.ssm_store_two
  ]
}
