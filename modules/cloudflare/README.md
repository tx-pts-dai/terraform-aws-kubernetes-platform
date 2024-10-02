# Cloudflare zone delegation

Deploy the Cloudflare delegation

```hcl
module "cloudflare" {
  source   = "tx-pts-dai/kubernetes-platform/aws//modules/cloudflare"
  version  = ...
  for_each = var.zones

  account_id   = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["accountId"]
  name_servers = module.route53_zones[each.key].route53_zone_name_servers[each.key]
  domain_name  = module.route53_zones[each.key].route53_zone_name[each.key]
}
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
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
| [cloudflare_record.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/record) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account id | `string` | n/a | yes |
| <a name="input_records"></a> [records](#input\_records) | List of records to create in Cloudflare | <pre>list(object({<br>    name    = string<br>    comment = optional(string, "Managed by Terraform")<br>    type    = string<br>    content = string<br>    ttl     = optional(number, 60)<br>  }))</pre> | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | The zone to create records in | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_records"></a> [records](#output\_records) | A map of cloudflare records |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
