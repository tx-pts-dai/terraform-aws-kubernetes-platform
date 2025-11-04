output "eks" {
  description = "eks module outputs"
  value       = module.k8s_platform.eks
}

output "zconfigure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.k8s_platform.eks.cluster_name} --alias ${module.k8s_platform.eks.cluster_name}"
}

output "karpenter" {
  description = "karpenter module outputs"
  value       = module.k8s_platform.karpenter
}

# Example outputs for Kubernetes access roles
# These will only have values if kubernetes_access_roles is configured
output "kubernetes_access_role_arns" {
  description = "Reusable IAM role ARNs for Kubernetes access - use these for AssumeRole operations"
  value       = module.k8s_platform.kubernetes_access_role_arns
}

output "kubernetes_access_roles" {
  description = "Detailed information about reusable Kubernetes access roles"
  value       = module.k8s_platform.kubernetes_access_roles
}
