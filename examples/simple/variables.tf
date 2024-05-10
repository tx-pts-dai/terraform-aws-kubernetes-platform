variable "region" {
  description = "The region to deploy the platform"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_admins" {
  description = "Map of IAM roles to add as cluster admins"
  type = map(object({
    role_name         = string
    kubernetes_groups = optional(list(string))
  }))
  default = {
    cicd = {
      role_name = "cicd-iac"
    }
  }
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "cluster_tags" {
  description = "Tags to set on the deployed resources"
  type        = map(string)
  default     = {}
}
