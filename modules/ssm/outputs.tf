output "stacks" {
  description = "List of stacks defined in SSM"
  value       = local.stacks
}

output "lookup" {
  description = "Map of looked up parameters"
  value       = local.lookup
}

output "filtered_parameters" {
  description = "List of parameters filtered by stack name prefix"
  value       = local.filtered_parameters
}

output "latest_stack_parameters" {
  description = "Latest stack parameters"
  value       = local.latest_stack_parameters
}

output "parameters" {
  description = "Parameters defined in SSM"
  value       = local.parameters
}
