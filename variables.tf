variable "name" {
  description = "The name of the platform"
  type        = string
}

variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  description = "Map of VPC configurations"
  type        = any
  default     = {}
}

variable "eks" {
  description = "Map of EKS configurations"
  type        = any
  default     = {}
}

variable "karpenter" {
  description = "Map of Karpenter configurations"
  type        = any
  default     = {}

  validation {
    condition     = try(var.karpenter.subnet_cidrs != null, false)
    error_message = "subnet_cidrs must be set when karpenter is enabled"
  }
}

variable "addons" {
  description = "Map of addon configurations"
  type        = any
  default = {
    aws_load_balancer_controller = { enabled = true }
    external_dns                 = { enabled = true }
    external_secrets             = { enabled = true }
    fargate_fluentbit            = { enabled = true }
    metrics_server               = { enabled = true }

    kube_prometheus_stack = { enabled = false }
    cert_manager          = { enabled = false }
    ingress_nginx         = { enabled = false }
  }
}

variable "base_domain" {
  description = "The base domain for the platform"
  type        = string
  default     = ""
}

variable "cluster_admins" {
  description = "Map of IAM roles to add as cluster admins"
  type = map(object({
    role_name         = string
    kubernetes_groups = optional(list(string))
  }))
  default = {}
}
