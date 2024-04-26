output "vpc" {
  description = "Map of attributes for the VPC"
  value       = module.vpc
}

output "networks" {
  value       = tolist(local.networks)
  description = "A list of network objects with name, az, hosts, and cidr_block."
}

output "network_cidr_blocks" {
  value       = tomap(local.network_by_name)
  description = "A map from network names to allocated address prefixes in CIDR notation."
}

output "grouped_networks" {
  value       = local.grouped_networks
  description = "A map of subnet names to their respective details and list of CIDR blocks."
}

output "cidr" {
  value       = var.cidr
  description = "The base CIDR block for the VPC"
}
