data "aws_ssm_parameters_by_path" "this" {
  path            = join("/", ["", var.base_prefix, var.stack_type])
  recursive       = true
  with_decryption = true
}

locals {
  # Create a map of parameters
  parameters = zipmap(data.aws_ssm_parameters_by_path.this.names, nonsensitive(data.aws_ssm_parameters_by_path.this.values))

  # Filter parameters by stack name prefix
  # Not sure if this is needed
  filtered_parameters = {
    for key, value in local.parameters : key => value
    if var.stack_name_prefix != "" && strcontains(key, var.stack_name_prefix)
  }

  # Extract stack names filtered by stack name prefix
  stacks = reverse(distinct([for key, _ in local.parameters : element(split("/", key), length(split("/", key)) - 2)
  if var.stack_name_prefix == "" || startswith(element(split("/", key), length(split("/", key)) - 2), var.stack_name_prefix)]))

  # Create a lookup map for stack-specific parameters
  lookup = {
    for stack in local.stacks : stack => {
      for lookup in var.lookup : lookup => try(
        element([for key, value in local.parameters : value
        if contains(split("/", key), stack) && contains(split("/", key), lookup)], 0),
        "" # Return empty string if the parameter is not found
      )
    }
  }

  # Identify the latest stack - since stacks are reversed, the latest stack is the first element
  latest_stack = try(local.stacks[0], null)
  # Extract parameters for the latest stack if latest_stack is not null
  latest_stack_parameters = local.latest_stack != null ? {
    for key, value in local.parameters : element(split("/", key), length(split("/", key)) - 1) => value...
    if strcontains(key, local.latest_stack)
  } : {}
}
