# Network Module

This module is a wrapper around the public VPC module with some additional configuration options suitable for the Tamedia platform.

See the [network example](../../example/network) how to use it and how to retrieve informations on the created resources from another stack.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.42 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.42 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ssm"></a> [ssm](#module\_ssm) | ./../ssm | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.ecr_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ecr_dkr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of availability zones to use | `number` | `3` | no |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | The CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Create the VPC | `bool` | `true` | no |
| <a name="input_create_vpc_endpoints"></a> [create\_vpc\_endpoints](#input\_create\_vpc\_endpoints) | Whether to create VPC endpoints for ECR and S3 | `bool` | `false` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Enable NAT Gateways | `bool` | `true` | no |
| <a name="input_enabled_vpc_endpoints_private_dns"></a> [enabled\_vpc\_endpoints\_private\_dns](#input\_enabled\_vpc\_endpoints\_private\_dns) | Whether to enable private DNS for VPC endpoints | `bool` | `true` | no |
| <a name="input_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#input\_secondary\_cidr\_blocks) | List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool | `list(string)` | `[]` | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single NAT Gateway | `bool` | `true` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | The stack name for the resources | `string` | n/a | yes |
| <a name="input_subnet_configs"></a> [subnet\_configs](#input\_subnet\_configs) | List of networks objects with their name and size in bits. The order of the list should not change. | `list(map(number))` | <pre>[<br/>  {<br/>    "public": 24<br/>  },<br/>  {<br/>    "private": 24<br/>  },<br/>  {<br/>    "intra": 26<br/>  },<br/>  {<br/>    "database": 26<br/>  },<br/>  {<br/>    "elasticache": 26<br/>  },<br/>  {<br/>    "redshift": 26<br/>  }<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_additional_cidr_blocks"></a> [additional\_cidr\_blocks](#output\_additional\_cidr\_blocks) | The additional CIDR blocks associated with the VPC |
| <a name="output_cidr"></a> [cidr](#output\_cidr) | The base CIDR block for the VPC |
| <a name="output_grouped_networks"></a> [grouped\_networks](#output\_grouped\_networks) | A map of subnet names to their respective list of CIDR blocks. |
| <a name="output_networks"></a> [networks](#output\_networks) | A list of network objects with name, az, hosts, and cidr\_block. |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | Map of attributes for the VPC |
| <a name="output_vpc_endpoint_ecr_api_id"></a> [vpc\_endpoint\_ecr\_api\_id](#output\_vpc\_endpoint\_ecr\_api\_id) | The ID of the ECR API VPC endpoint |
| <a name="output_vpc_endpoint_ecr_dkr_id"></a> [vpc\_endpoint\_ecr\_dkr\_id](#output\_vpc\_endpoint\_ecr\_dkr\_id) | The ID of the ECR DKR VPC endpoint |
| <a name="output_vpc_endpoint_s3_id"></a> [vpc\_endpoint\_s3\_id](#output\_vpc\_endpoint\_s3\_id) | The ID of the S3 VPC endpoint |
| <a name="output_vpc_endpoints_security_group_id"></a> [vpc\_endpoints\_security\_group\_id](#output\_vpc\_endpoints\_security\_group\_id) | The ID of the VPC endpoints security group |
<!-- END_TF_DOCS -->

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
