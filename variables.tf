variable "environment" {
  description = "The name of the environment"
  type        = string
}

variable "github_repo" {
  description = "The name of the GitHub repository"
  type        = string
}

# variable "clusters" {
#   description = "EKS cluster definitions"
#   type        = any
#   default     = {}
# }

variable "eks" {
  description = "EKS cluster configuration"
  type        = any
  default     = {}
}

variable "karpenter" {
  description = "Karpenter configuration"
  type        = any
  default     = {}
}