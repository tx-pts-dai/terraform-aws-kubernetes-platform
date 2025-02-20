output "eks" {
  description = "Map of attributes for the EKS cluster"
  value       = module.eks
}

output "eks_cluster_version" {
  description = "Current EKS cluster version"
  value       = module.eks.cluster_version
}

output "network" {
  description = "Map of attributes for the VPC module"
  value       = module.network
}

output "karpenter" {
  description = "Map of attributes for the Karpenter module"
  value       = module.karpenter
}
