# Security Group Module

This module creates a security group and rules.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create"></a> [create](#input\_create) | Create the security group. | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | The description of the security group. | `string` | `""` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | The egress rules for the security group. | <pre>map(object({<br/>    type                     = string<br/>    protocol                 = string<br/>    from_port                = number<br/>    to_port                  = number<br/>    description              = optional(string)<br/>    cidr_blocks              = optional(list(string))<br/>    ipv6_cidr_blocks         = optional(list(string))<br/>    prefix_list_ids          = optional(list(string))<br/>    self                     = optional(bool)<br/>    source_security_group_id = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | The ingress rules for the security group. | <pre>map(object({<br/>    type                     = string<br/>    protocol                 = string<br/>    from_port                = number<br/>    to_port                  = number<br/>    description              = optional(string)<br/>    cidr_blocks              = optional(list(string))<br/>    ipv6_cidr_blocks         = optional(list(string))<br/>    prefix_list_ids          = optional(list(string))<br/>    self                     = optional(bool)<br/>    source_security_group_id = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the security group, this name must be unique within the VPC. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC id to create the security group in. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
