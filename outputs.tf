output "eks" {
  description = "Map of attributes for the EKS cluster"
  value       = module.eks
}

output "network" {
  description = "Map of attributes for the VPC module"
  value       = module.network
}

output "karpenter" {
  description = "Map of attributes for the Karpenter module"
  value       = module.karpenter
}

output "argocd" {
  description = "Map of attributes for the ArgoCD module"
  value       = module.argocd
}
