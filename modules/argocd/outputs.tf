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

output "argocd_parameter_arn" {
  description = "ARN of the ArgoCD cluster configuration in SSM Parameter Store"
  value       = try(aws_ssm_parameter.argocd_cluster[0].arn, "")
}

output "argocd_parameter_name" {
  description = "Name of the ArgoCD cluster configuration in SSM Parameter Store"
  value       = try(aws_ssm_parameter.argocd_cluster[0].name, "")
}
