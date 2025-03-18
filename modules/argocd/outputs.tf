output "iam_role_arn" {
  description = "IAM Role ARN for ArgoCD"
  value       = local.iam_role_arn
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}

output "cluster_secret_yaml" {
  description = "ArgoCD cluster secret YAML configuration"
  value       = local.cluster_secret_yaml
}
