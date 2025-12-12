terraform {
  required_version = "~> 1.10"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "modules/cloudflare/examples/simple.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    use_lockfile         = true
    region               = "eu-central-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

data "aws_secretsmanager_secret_version" "cloudflare" {
  secret_id = "dai/cloudflare/tamedia/apiToken"
}

provider "cloudflare" {
  api_token = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["apiToken"]
}

locals {
  zones = {
    "kaas-cloudflare.tamedia.tech" = {
      comment = "KaaS cloudflare zone"
    }
  }
}

module "cloudflare" {
  source = "../../cloudflare"

  for_each = local.zones

  zone_name    = each.key
  comment      = "Managed by KAAS examples"
  name_servers = [for i in range(4) : module.route53_zones[each.key].name_servers[i]]
  account_id   = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["accountId"]
}

module "route53_zones" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.1.1"

  for_each = local.zones

  name    = each.key
  comment = lookup(each.value, "comment", null)

}
