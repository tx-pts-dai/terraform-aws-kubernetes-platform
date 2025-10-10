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

## VPC Endpoints
output "vpc_endpoint_ecr_api_id" {
  description = "The ID of the ECR API VPC endpoint"
  value       = try(aws_vpc_endpoint.ecr_api[0].id, null)
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "The ID of the ECR DKR VPC endpoint"
  value       = try(aws_vpc_endpoint.ecr_dkr[0].id, null)
}

output "vpc_endpoint_s3_id" {
  description = "The ID of the S3 VPC endpoint"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "vpc_endpoints_security_group_id" {
  description = "The ID of the VPC endpoints security group"
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
}
