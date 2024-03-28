output "eks" {
  description = "Map of attributes for the EKS cluster"
  value       = module.eks
}

output "network" {
  description = "Map of attributes for the EKS cluster"
  value       = module.network
}
