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

variable "hub_iam_role_arn" {
  description = "IAM Role ARN for ArgoCD Hub"
  type        = string

  default = null
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "labels" {
  description = "Labels to add to the ArgoCD Cluster Secret"
  type        = map(string)

  default = {}
}
variable "values" {
  description = "Values to pass to the Helm chart"
  type        = list(string)

  default = []
}

variable "set" {
  description = "Set values to pass to the Helm chart"
  type        = list(string)

  default = []
}
