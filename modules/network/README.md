# Network Module

This module is a wrapper around the public VPC module with some additional configuration options suitable for the Tamedia platform.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.42.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.42.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ssm"></a> [ssm](#module\_ssm) | ./../ssm | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 5.8.1 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of availability zones to use | `number` | `3` | no |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | The CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Create the VPC | `bool` | `true` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Enable NAT Gateways | `bool` | `true` | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single NAT Gateway | `bool` | `true` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | The stack name for the resources | `string` | n/a | yes |
| <a name="input_subnet_configs"></a> [subnet\_configs](#input\_subnet\_configs) | List of networks objects with their name and size in bits. The order of the list should not change. | `list(map(number))` | <pre>[<br>  {<br>    "public": 24<br>  },<br>  {<br>    "private": 24<br>  },<br>  {<br>    "intra": 26<br>  },<br>  {<br>    "database": 26<br>  },<br>  {<br>    "redshift": 26<br>  },<br>  {<br>    "karpenter": 22<br>  }<br>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cidr"></a> [cidr](#output\_cidr) | The base CIDR block for the VPC |
| <a name="output_grouped_networks"></a> [grouped\_networks](#output\_grouped\_networks) | A map of subnet names to their respective details and list of CIDR blocks. |
| <a name="output_network_cidr_blocks"></a> [network\_cidr\_blocks](#output\_network\_cidr\_blocks) | A map from network names to allocated address prefixes in CIDR notation. |
| <a name="output_networks"></a> [networks](#output\_networks) | A list of network objects with name, az, hosts, and cidr\_block. |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | Map of attributes for the VPC |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.42.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.42.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 5.8.1 |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of availability zones to use | `number` | `3` | no |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | The CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Create the VPC | `bool` | `true` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Enable NAT Gateways | `bool` | `true` | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single NAT Gateway | `bool` | `true` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | The stack name for the resources | `string` | n/a | yes |
| <a name="input_subnet_configs"></a> [subnet\_configs](#input\_subnet\_configs) | List of networks objects with their name and size in bits. The order of the list should not change. | `list(map(number))` | <pre>[<br>  {<br>    "public": 24<br>  },<br>  {<br>    "private": 24<br>  },<br>  {<br>    "intra": 26<br>  },<br>  {<br>    "database": 26<br>  },<br>  {<br>    "redshift": 26<br>  },<br>  {<br>    "karpenter": 22<br>  }<br>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cidr"></a> [cidr](#output\_cidr) | The base CIDR block for the VPC |
| <a name="output_grouped_networks"></a> [grouped\_networks](#output\_grouped\_networks) | A map of subnet names to their respective details and list of CIDR blocks. |
| <a name="output_network_cidr_blocks"></a> [network\_cidr\_blocks](#output\_network\_cidr\_blocks) | A map from network names to allocated address prefixes in CIDR notation. |
| <a name="output_networks"></a> [networks](#output\_networks) | A list of network objects with name, az, hosts, and cidr\_block. |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | Map of attributes for the VPC |
<!-- END_TF_DOCS -->
