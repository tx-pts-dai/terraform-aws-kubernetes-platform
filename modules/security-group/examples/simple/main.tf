terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "modules/security-groups/examples/simple.tfstate"
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

module "security_group" {
  source = "./../../"

  name        = "ex-security-group"
  description = "Example security group"

  vpc_id = "vpc-12345678"

  ingress_rules = {
    http = {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 8080
      to_port     = 8080
      cidr_blocks = ["10.240.0.0/16"]
    }
    https = {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = ["10.240.0.0/16"]
    }
  }
  egress_rules = {
    all = {
      type        = "egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
