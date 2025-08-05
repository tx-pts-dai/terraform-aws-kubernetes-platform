output "eks" {
  description = "eks module outputs"
  value       = module.k8s_platform.eks
}

output "network" {
  description = "network module outputs"
  value       = module.network
}

output "zconfigure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.k8s_platform.eks.cluster_name} --alias ${module.k8s_platform.eks.cluster_name}"
}

output "karpenter" {
  description = "karpenter module outputs"
  value       = module.k8s_platform.karpenter
}
