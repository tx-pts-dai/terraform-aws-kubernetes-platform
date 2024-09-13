variable "create" {
  description = "Create the platform resources. if set to false, no resources will be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "The name of the platform, a timestamp will be appended to this name to make the stack_name. If not provided, the name of the directory will be used."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# TODO: Split out into dedicated variables
variable "vpc" {
  description = "Map of VPC configurations"
  type        = any
  default     = {}
}

# TODO: Split out into dedicated variables
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

################################################################################
# Integrations

variable "base_domain" {
  description = "Base domain for the platform, used for ingress and ACM certificates"
  type        = string
  default     = "test"
}

variable "enable_acm_certificate" {
  description = "Enable ACM certificate"
  type        = bool
  default     = false
}

variable "acm_certificate" {
  description = "ACM certificate configuration. If wildcard_certificates is true, all domains will include a wildcard prefix."
  type = object({
    domain_name               = optional(string) # Overrides base_domain
    subject_alternative_names = optional(list(string), [])
    wildcard_certificates     = optional(bool, false)
    wait_for_validation       = optional(bool, false)
  })
  default = {}
}

variable "enable_okta" {
  description = "Enable Okta integration"
  type        = bool
  default     = false
}

variable "okta" {
  description = "Okta configurations"
  type = object({
    base_url                    = optional(string, "")
    secrets_manager_secret_name = optional(string, "")
    kubernetes_secret_name      = optional(string, "okta")
  })
  default = {}
}

variable "enable_pagerduty" {
  description = "Enable PagerDuty integration"
  type        = bool
  default     = false
}

variable "pagerduty" {
  description = "PagerDuty configurations"
  type = object({
    secrets_manager_secret_name = optional(string, "")
    kubernetes_secret_name      = optional(string, "pagerduty")
  })
  default = {}
}

################################################################################
# Core Addons - Installed by default

variable "enable_karpenter" {
  description = "Enable Karpenter"
  type        = bool
  default     = true
}

variable "karpenter" {
  description = "Karpenter configurations"
  type        = any
  default     = {}
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

variable "metrics_server" {
  description = "Metrics Server configurations"
  type        = any
  default     = {}
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller" {
  description = "AWS Load Balancer Controller configurations"
  type        = any
  default     = {}
}

variable "enable_external_dns" {
  description = "Enable External DNS"
  type        = bool
  default     = true
}

variable "external_dns" {
  description = "External DNS configurations"
  type        = any
  default     = {}
}

variable "enable_external_secrets" {
  description = "Enable External Secrets"
  type        = bool
  default     = true
}

variable "external_secrets" {
  description = "External Secrets configurations"
  type        = any
  default     = {}
}

################################################################################
# Logging and Monitoring

variable "enable_fargate_fluentbit" {
  description = "Enable Fargate Fluentbit"
  type        = bool
  default     = true
}

variable "fargate_fluentbit" {
  description = "Fargate Fluentbit configurations"
  type        = any
  default     = {}
}

variable "enable_fluent_operator" {
  description = "Enable fluent operator"
  type        = bool
  default     = true
}

variable "fluent_operator" {
  description = "Fluent configurations"
  type        = any
  default     = {}
}

variable "fluent_log_annotation" {
  description = "Pod Annotation required to enable fluent bit logging. Setting name to empty string will disable annotation requirement."
  type = object({
    name  = optional(string, "fluentbit.io/include")
    value = optional(string, "true")
  })
  default = {}
}

variable "fluent_cloudwatch_retention_in_days" {
  description = "Number of days to keep logs in cloudwatch"
  type        = string
  default     = "7"

}

variable "enable_prometheus_stack" {
  description = "Enable Prometheus stack"
  type        = bool
  default     = true
}

variable "prometheus_stack" {
  description = "Prometheus stack configurations"
  type        = any
  default     = {}
}

variable "enable_amp" {
  description = "Enable AWS Managed Prometheus"
  type        = bool
  default     = false
}

variable "enable_grafana" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "grafana" {
  description = "Grafana configurations, used to override default configurations"
  type        = any
  default     = {}
}

################################################################################
# Additional Addons - Not installed by default

variable "enable_cert_manager" {
  description = "Enable Cert Manager"
  type        = bool
  default     = false
}

variable "cert_manager" {
  description = "Cert Manager configurations"
  type        = any
  default     = {}
}

variable "enable_ingress_nginx" {
  description = "Enable Ingress Nginx"
  type        = bool
  default     = false
}

variable "ingress_nginx" {
  description = "Ingress Nginx configurations"
  type        = any
  default     = {}
}

variable "enable_downscaler" {
  description = "Enable Downscaler"
  type        = bool
  default     = false
}

variable "downscaler" {
  description = "Downscaler configurations"
  type        = any
  default     = {}
}
