output "stacks" {
  description = "List of stacks"
  value       = module.ssm_lookup_latest_stack_parameters.stacks

}
output "latest_stack_parameters" {
  description = "Latest stack parameters"
  value       = module.ssm_lookup_latest_stack_parameters.latest_stack_parameters
}
