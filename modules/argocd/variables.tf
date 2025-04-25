variable "create" {
  description = "Create the ArgoCD resources"
  type        = bool

  default = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
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

variable "cluster_secret_labels" {
  description = "Labels to add to the ArgoCD Cluster Secret"
  type        = map(string)

  default = {}
}

variable "cluster_secret_suffix" {
  description = "Suffix to add to the ArgoCD Cluster Secret. This will show in the ArgoCD UI"
  type        = string

  default = ""
}

variable "helm_values" {
  description = "Values to pass to the Helm chart"
  type        = list(string)

  default = []
}

variable "helm_set" {
  description = "Set values to pass to the Helm chart"
  type        = list(string)

  default = []
}
