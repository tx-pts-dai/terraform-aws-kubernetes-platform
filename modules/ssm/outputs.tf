output "stacks" {
  description = "List of stacks defined in SSM ordered by creation date (latest first)"
  value       = local.stacks
}

output "lookup" {
  description = "Map of parameters from filtered parameters containing only keys defined in lookup"
  value       = local.lookup
}

output "filtered_parameters" {
  description = "List of parameters filtered by stack name prefix"
  value       = local.filtered_parameters
}

output "latest_stack_parameters" {
  description = "Latest created stack parameters"
  value       = local.latest_stack_parameters
}

output "parameters" {
  description = "All parameters defined in SSM"
  value       = local.parameters
}
