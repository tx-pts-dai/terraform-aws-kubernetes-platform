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

variable "cluster_admins" {
  description = "Map of IAM roles to add as cluster admins. Only exact matching role names are returned"
  type = map(object({
    role_name         = string
    kubernetes_groups = optional(list(string))
  }))
  default = {}
}

variable "base_domain" {
  description = "Base domain for the platform, used for ingress and ACM certificates"
  type        = string
  default     = "test"
}

variable "acm_certificate" {
  description = "ACM certificate configuration. If wildcard_certificates is true, all domains will include a wildcard prefix."
  type = object({
    enabled                   = optional(bool, false)
    domain_name               = optional(string) # Overrides base_domain
    subject_alternative_names = optional(list(string), [])
    wildcard_certificates     = optional(bool, false)
    wait_for_validation       = optional(bool, false)
  })
  default = {}
}

variable "karpenter" {
  description = "Karpenter configurations"
  type = object({
    enabled = optional(bool, true)
  })
  default = {}
}

variable "prometheus_stack" {
  description = "Prometheus stack configurations"
  type = object({
    enabled = optional(bool, true)
  })
  default = {}
}

variable "grafana" {
  description = "Grafana configurations"
  type = object({
    enabled = optional(bool, true)
  })
  default = {}
}

variable "okta_integration" {
  description = "Okta integration configurations"
  type = object({
    enabled                     = optional(bool, true)
    base_url                    = optional(string)
    secrets_manager_secret_name = optional(string)
  })
  default = {}
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

    cert_manager  = { enabled = false }
    ingress_nginx = { enabled = false }
    downscaler    = { enabled = false }
  }
}

variable "logging_annotation" {
  description = "Annotation kaas pods should have to get they logs stored in cloudwatch"
  type = object({
    name  = string
    value = string
  })
  default = {
    name  = "kaas.tamedia.ch/logging"
    value = "true"
  }
}

variable "logging_retention_in_days" {
  description = "How log to keep kaas logs in cloudwatch"
  type        = string
  default     = 7
}
