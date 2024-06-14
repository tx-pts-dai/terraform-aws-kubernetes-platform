terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/cloudflare_delegation.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    dynamodb_table       = "terraform-lock"
    region               = "eu-central-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

data "aws_secretsmanager_secret" "cloudflare" {
  name = "dai/cloudflare/tamedia/apiToken"
}

data "aws_secretsmanager_secret_version" "cloudflare" {
  secret_id = data.aws_secretsmanager_secret.cloudflare.id
}

provider "cloudflare" {
  api_token = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["apiToken"]
}

module "cloudflare_delegation" {
  source       = "../../modules/cloudflare_delegation"
  for_each     = var.zones
  domain_name  = module.route53_zones[each.key].route53_zone_name[each.key]
  name_servers = module.route53_zones[each.key].route53_zone_name_servers[each.key]
  account_id   = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["accountId"]
}

module "route53_zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "2.11.1"

  for_each = var.zones

  zones = {
    (each.key) = {
      comment = each.value.comment
    }
  }
}
