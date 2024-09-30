# SSM Parameter Store for Terraform Outputs

## Overview

This Terraform module is designed to store Terraform outputs in AWS Systems Manager (SSM) Parameter Store and provide functionality to look up parameters for cross stack reference. It helps store and retrieve parameters across different terraform stacks and environments.

## Features

- Store parameters in SSM Parameter Store with customizable hierarchies.
- Retrieve parameters from SSM Parameter Store based on specified paths.
- Retrieve list of stack names and parameters.
- Filter stacks with prefixes.
- Support for securely storing sensitive parameters.
- Dynamically identify and retrieve the latest stack parameters.

## Example

Store parameters in SSM Parameter Store:
```hcl
module "ssm_parameters" {
  source           = "./path-to-your-module"

  base_prefix      = "infrastructure"
  stack_type       = "platform"
  stack_name       = "stack-123"

  parameters = {
    cluster_endpoint = {
      type           = "String"
      insecure_value = "https://cluster-zxcv.local"
    }
    cluster_name = {
      insecure_value = "cluster-123"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

Retrieve parameters from SSM Parameter Store:
```hcl
module "ssm_lookup" {
  source           = "./path-to-your-module"

  base_prefix       = "infrastructure"
  stack_type        = "platform"
  stack_name_prefix = "stack-"

  lookup = [
    "cluster_endpoint",
    "cluster_name"
  ]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

Outputs:
```hcl
ssm_lookup = {
  "filtered_parameters" = {
    "/infrastructure/platform/stack-123/cluster_endpoint" = "cluster-zxcv"
    "/infrastructure/platform/stack-123/cluster_name" = "foo"
    "/infrastructure/platform/stack-234/cluster_endpoint" = "cluster-asjf"
    "/infrastructure/platform/stack-234/cluster_name" = "bar"
  }
  "latest_stack_parameters" = {
    "/infrastructure/platform/stack-234/cluster_endpoint" = "https://cluster-asjf.local"
    "/infrastructure/platform/stack-234/cluster_name" = "bar"
  }
  "lookup" = {
    "stack-123" = {
      "cluster_endpoint" = "https://cluster-zxcv.local"
      "cluster_name" = "foo"
    }
    "stack-234" = {
      "cluster_endpoint" = "https://cluster-asjf.local"
      "cluster_name" = "bar"
    }
  }
  # All parameters stored in SSM
  "parameters" = tomap({
    "/infrastructure/platform/stack-123/cluster_endpoint" = "https://cluster-zxcv.local"
    "/infrastructure/platform/stack-123/cluster_name" = "foo"
    "/infrastructure/platform/stack-234/cluster_endpoint" = "https://cluster-asjf.local"
    "/infrastructure/platform/stack-234/cluster_name" = "bar"
  })
  "stacks" = tolist([
    "stack-123",
    "stack-234",
  ])
}
```


## Implementation Details

### Storing Parameters

Parameters are stored in SSM Parameter Store using the `aws_ssm_parameter` resource. The parameter name is constructed using the `base_prefix`, `stack_type`, and `stack_name`, forming a hierarchy.

### Retrieving Parameters

The module uses the `aws_ssm_parameters_by_path` data source to retrieve parameters from SSM Parameter Store based on the specified path. The retrieved parameters are processed to:

- Filter parameters by stack name prefix.
- Extract unique stack names.
- Create a lookup map for stack-specific parameters.
- Identify and retrieve the latest stack parameters.

### Filtering and Lookup

The `filtered_parameters` local variable is used to filter parameters based on the stack name prefix. The `lookup` local variable creates a nested map of stack-specific parameters based on the provided lookup list. The `latest_stack_parameters` local variable identifies and retrieves parameters for the last created stack since we use timestamps in the stack names suffix.

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
| [aws_ssm_parameters_by_path.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base_prefix"></a> [base\_prefix](#input\_base\_prefix) | Base SSM namespace prefix for the parameters | `string` | `"infrastructure"` | no |
| <a name="input_create"></a> [create](#input\_create) | Create the SSM parameters | `bool` | `true` | no |
| <a name="input_lookup"></a> [lookup](#input\_lookup) | List of parameters to Lookup | `list(any)` | `[]` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Map of SSM parameters to create | <pre>map(object({<br>    name           = optional(string)<br>    type           = optional(string, "String")<br>    value          = optional(string)<br>    insecure_value = optional(string)<br>  }))</pre> | `{}` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | The name of the stack | `string` | `null` | no |
| <a name="input_stack_name_prefix"></a> [stack\_name\_prefix](#input\_stack\_name\_prefix) | Filter all stacks that include this prefix in the name. | `string` | `""` | no |
| <a name="input_stack_type"></a> [stack\_type](#input\_stack\_type) | The type of terraform stack to be used in the namespace prefix. platform, network, account, shared | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_filtered_parameters"></a> [filtered\_parameters](#output\_filtered\_parameters) | List of parameters filtered by stack name prefix |
| <a name="output_latest_stack_parameters"></a> [latest\_stack\_parameters](#output\_latest\_stack\_parameters) | Latest created stack parameters |
| <a name="output_lookup"></a> [lookup](#output\_lookup) | Map of parameters from filtered parameters containing only keys defined in lookup |
| <a name="output_parameters"></a> [parameters](#output\_parameters) | All parameters defined in SSM |
| <a name="output_stacks"></a> [stacks](#output\_stacks) | List of stacks defined in SSM ordered by creation date (latest first) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Contributions

Contributions to enhance the functionality and flexibility of this module are welcome. Please submit a pull request or open an issue to discuss any changes.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---
