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
