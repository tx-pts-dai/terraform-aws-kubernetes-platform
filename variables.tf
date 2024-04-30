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
}

variable "enable_datadog" {
  description = "Enable Datadog integration"
  type        = bool
  default     = false
}

variable "datadog" {
  description = "Map of Datadog configurations"
  type        = any
  default = {
    site = "datadoghq.eu"
    agent_api_key_name = "kubernetes-platform-example"
    agent_app_key_name = "kubernetes-platform-example"
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
    downscaler            = { enabled = false }
  }
}

variable "base_domain" {
  description = "The base domain for the platform"
  type        = string
  default     = ""
}

variable "cluster_admins" {
  description = "Map of IAM roles to add as cluster admins. Only exact matching role names are returned"
  type = map(object({
    role_name         = string
    kubernetes_groups = optional(list(string))
  }))
  default = {}
}
