output "stacks" {
  description = "List of stacks defined in SSM"
  value       = local.stacks
}

output "clusters" {
  description = "List of clusters defined in SSM"
  value       = local.clusters
}

output "filtered_parameters" {
  description = "List of parameters filtered by stack name prefix"
  value       = local.filtered_parameters
}
