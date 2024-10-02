terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "modules/cloudflare/examples/simple.tfstate"
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

data "aws_secretsmanager_secret_version" "cloudflare" {
  secret_id = "dai/cloudflare/apiToken"
}

provider "cloudflare" {
  api_token = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["apiToken"]
}

module "route53_zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "2.11.1"

  zones = var.zones
}

module "cloudflare" {
  source = "./../../cloudflare"

  for_each = var.zones

  account_id = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["accountId"]
  zone_name  = "example.ch"

  records = [
    for i in range(4) : {
      name    = each.key
      type    = "NS"
      content = module.route53_zones.route53_zone_name_servers[each.key][i]
      ttl     = 3600
    }
  ]
}
