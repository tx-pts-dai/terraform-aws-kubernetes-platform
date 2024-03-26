output "eks" {
  description = "Map of attributes for the EKS cluster"
  value       = module.eks
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "vpc_cidr_block" {
  description = "vpc_cidr_block"
  value       = module.vpc.vpc_cidr_block
}
