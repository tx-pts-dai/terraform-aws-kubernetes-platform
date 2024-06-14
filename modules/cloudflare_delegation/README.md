# Cloudflare zone delegation

Deploy the Cloudflare delegation


```hcl
module "cloudflare_delegation" {
  source                   = "../../modules/cloudflare_delegation"
  for_each                 = var.zones
  domain_name              = module.route53_zones[each.key].route53_zone_name[each.key]
  aws_route53_name_servers = module.route53_zones[each.key].route53_zone_name_servers[each.key]
  account_id               = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["accountId"]
}
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_record.ns](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/record) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account id | `string` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name to delegate in Cloudflare | `string` | n/a | yes |
| <a name="input_name_servers"></a> [name\_servers](#input\_name\_servers) | Name servers to delegate to | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
