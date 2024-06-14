# Datadog

Deploy the Cloudflare delegation

```hcl
module "cloudflare_delegation" {
  source = "tx-pts-dai/kubernetes-platform/aws//modules/cloudflare_delegation"
  version = ...
  for_each                 = var.zones
  domain_name              = module.route53_zones[each.key].name
  aws_route53_name_servers = module.route53_zones[each.key].name_servers
  account_id               = var.cloudflare_account_id
  secret_name              = var.cloudflare_secret_name
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
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account id | `string` | n/a | yes |
| <a name="input_aws_route53_name_servers"></a> [aws\_route53\_name\_servers](#input\_aws\_route53\_name\_servers) | Route53 name servers | `list(string)` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name to delegate in Cloudflare | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
