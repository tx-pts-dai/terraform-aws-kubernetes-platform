variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "create" {
  description = "Create the ArgoCD resources"
  type        = bool

  default = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)

  default = {}
}

variable "enable_hub" {
  description = "Enable ArgoCD Hub"
  type        = bool

  default = false
}

variable "enable_spoke" {
  description = "Enable ArgoCD Spoke"
  type        = bool

  default = false
}

variable "hub_iam_role_name" {
  description = "IAM Role Name for ArgoCD Hub. This is referenced by the Spoke clusters"
  type        = string

  default = "argocd-controller"
}

variable "hub_iam_role_arn" {
  description = "(Deprecated, use hub_iam_role_arns) IAM Role ARN for ArgoCD Hub. This is required for spoke clusters"
  type        = string

  default = null
}

variable "hub_iam_role_arns" {
  description = "A list of ArgoCD Hub IAM Role ARNs, enabling hubs to access spoke clusters. This is required for spoke clusters."
  type        = list(string)

  default = null
}

variable "namespace" {
  description = "Namespace to deploy ArgoCD"
  type        = string

  default = "argocd"
}
