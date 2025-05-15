output "hub_iam_role_arn" {
  description = "IAM Role ARN for ArgoCD"
  value       = try(aws_iam_role.argocd_controller[0].arn, "")
}

output "spoke_iam_role_arn" {
  description = "IAM Role ARN for ArgoCD Spoke"
  value       = try(aws_iam_role.argocd_spoke[0].arn, "")
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}
