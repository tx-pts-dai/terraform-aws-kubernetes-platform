# SSM Module

Manage AWS Systems Manager (SSM) parameters for the Tamedia platform.

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

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.cluster_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.cluster_name_latest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameters_by_path.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base_prefix"></a> [base\_prefix](#input\_base\_prefix) | Base SSM prefix for the platform parameters | `string` | `"/infrastructure"` | no |
| <a name="input_latest"></a> [latest](#input\_latest) | Set parameters in latest namespace | `bool` | `false` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Map of SSM parameters to create | <pre>map(object({<br>    name           = string<br>    type           = optional(string, "String")<br>    value          = optional(string)<br>    insecure_value = optional(string)<br>  }))</pre> | `{}` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | The name of the platform | `string` | `null` | no |
| <a name="input_stack_name_prefix"></a> [stack\_name\_prefix](#input\_stack\_name\_prefix) | The prefix for the stack name | `string` | `""` | no |
| <a name="input_stack_type"></a> [stack\_type](#input\_stack\_type) | The type of the terraform stack | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_clusters"></a> [clusters](#output\_clusters) | List of clusters defined in SSM |
| <a name="output_filtered_parameters"></a> [filtered\_parameters](#output\_filtered\_parameters) | List of parameters filtered by stack name prefix |
| <a name="output_stacks"></a> [stacks](#output\_stacks) | List of stacks defined in SSM |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
