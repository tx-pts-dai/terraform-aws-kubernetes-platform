output "vpc" {
  description = "Map of attributes for the VPC"
  value       = module.vpc
}

output "networks" {
  value       = tolist(local.networks)
  description = "A list of network objects with name, az, hosts, and cidr_block."
}

output "cidr" {
  value       = module.vpc.vpc_cidr_block
  description = "The base CIDR block for the VPC"
}

output "additional_cidr_blocks" {
  value       = module.vpc.vpc_secondary_cidr_blocks
  description = "The additional CIDR blocks associated with the VPC"
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
