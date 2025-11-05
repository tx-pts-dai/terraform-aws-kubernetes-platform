output "eks" {
  description = "Map of attributes for the EKS cluster"
  value       = module.eks
}

output "karpenter" {
  description = "Map of attributes for the Karpenter module"
  value       = module.karpenter
}

output "argocd" {
  description = "Map of attributes for the ArgoCD module"
  value       = module.argocd
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
