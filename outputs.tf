output "eks" {
  description = "Map of attributes for the EKS cluster"
  value       = module.eks
}

output "karpenter" {
  description = "Map of attributes for the self-managed Karpenter module (empty when enable_karpenter is false)"
  value       = module.karpenter
}

output "auto_mode_node_iam_role_arn" {
  description = "ARN of the EKS Auto Mode node IAM role (null when Auto Mode is disabled). Reference this from custom NodeClasses."
  value       = try(module.eks.node_iam_role_arn, null)
}

output "auto_mode_node_iam_role_name" {
  description = "Name of the EKS Auto Mode node IAM role (null when Auto Mode is disabled)."
  value       = try(module.eks.node_iam_role_name, null)
}

output "argocd" {
  description = "Map of attributes for the self-managed ArgoCD module"
  value       = module.argocd
}

output "argocd_capability" {
  description = "Map of attributes for the AWS-managed ArgoCD EKS capability (empty when disabled)"
  value       = module.argocd_capability
}

output "argocd_capability_server_url" {
  description = "URL of the AWS-managed ArgoCD server (null when the capability is disabled)"
  value       = try(module.argocd_capability.argocd_server_url, null)
}

output "ack" {
  description = "Map of attributes for the ACK EKS capability"
  value       = module.ack_capability
}

output "kubernetes_access_role_arns" {
  description = "Map of reusable Kubernetes access role names to their IAM role ARNs"
  value = {
    for k, v in aws_iam_role.k8s_access : k => v.arn
  }
}

output "kubernetes_access_roles" {
  description = "Detailed information about reusable Kubernetes access IAM roles"
  value = {
    for k, v in aws_iam_role.k8s_access : k => {
      role_arn                 = v.arn
      role_name                = v.name
      access_level             = var.kubernetes_access_roles[k].access_level
      scope                    = var.kubernetes_access_roles[k].scope
      namespaces               = var.kubernetes_access_roles[k].scope == "namespace" ? var.kubernetes_access_roles[k].namespaces : []
      controller_iam_role_arns = var.kubernetes_access_roles[k].controller_iam_role_arns
    }
  }
}
