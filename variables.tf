variable "name" {
  description = "The name of the platform, a timestamp will be appended to this name to make the stack_name"
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
    set = optional(list(object({
      name  = string
      value = string
    })))
  })
  default = {}
}

variable "fluent_operator" {
  description = "Fluent configurations. If enabled, fluentbit will be deployed.\n log_annotation is the annotation to add to pods to get logs stored in cloudwatch\n cloudwatch_retention_in_days is the number of days to keep logs in cloudwatch"
  type = object({
    enabled = optional(bool, true)
    log_annotation = optional(object({
      name  = optional(string)
      value = optional(string)
    }), { name = "kaas.tamedia.ch/logging", value = "true" })
    cloudwatch_retention_in_days = optional(string, "7")
  })
  default = {}
}

variable "prometheus_stack" {
  description = "Prometheus stack configurations"
  type = object({
    enabled = optional(bool, true)
    set = optional(list(object({
      name  = string
      value = string
    })))
  })
  default = {}
}

variable "grafana" {
  description = "Grafana configurations"
  type = object({
    enabled = optional(bool, true)
    set = optional(list(object({
      name  = string
      value = string
    })))
  })
  default = {}
}

variable "pagerduty_integration" {
  description = "PagerDuty integration configurations"
  type = object({
    enabled                     = optional(bool, false)
    secrets_manager_secret_name = optional(string)
    kubernetes_secret_name      = optional(string, "pagerduty")
    routing_key                 = optional(string)
  })
  default = {}

}
variable "okta_integration" {
  description = "Okta integration configurations"
  type = object({
    enabled                     = optional(bool, true)
    base_url                    = optional(string)
    secrets_manager_secret_name = optional(string)
    kubernetes_secret_name      = optional(string, "okta")
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
