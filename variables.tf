variable "metadata" {
  description = "Metadata for the platform"
  type = object({
    environment = optional(string, "")
    team        = optional(string, "")
  })
  default = {}
}

variable "create_addons" {
  description = "Create the platform addons. if set to false, no addons will be created"
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
  default     = null
}

variable "enable_acm_certificate" {
  description = "Enable ACM certificate"
  type        = bool
  default     = false
}

variable "acm_certificate" {
  description = <<-EOT
  ACM certificate configuration for the domain(s). Controls domain name, alternative domain names, wildcard configuration, and validation behavior.
  Options include:
    - domain_name: Primary domain name for the certificate. If not provided, uses base_domain from other configuration.
    - subject_alternative_names: List of additional domain names to include in the certificate.
    - wildcard_certificates: When true, adds a wildcard prefix (*.) to all domains in the certificate.
    - prepend_stack_id: When true, prepends the stack identifier to each domain name. Only works after random_string is created.
    - wait_for_validation: When true, Terraform will wait for certificate validation to complete before proceeding.
  EOT
  type = object({
    domain_name               = optional(string)
    subject_alternative_names = optional(list(string), [])
    wildcard_certificates     = optional(bool, false)
    prepend_stack_id          = optional(bool, false)
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

variable "enable_slack" {
  description = "Enable Slack integration"
  type        = bool
  default     = false
}

variable "slack" {
  description = "Slack configurations"
  type = object({
    secrets_manager_secret_name = optional(string, "")
    kubernetes_secret_name      = optional(string, "slack")
  })
  default = {}
}

################################################################################
# Core Addons - Installed by default

variable "karpenter_helm_values" {
  description = "List of Karpenter Helm values"
  type        = list(string)
  default     = []
}

variable "karpenter_helm_set" {
  description = "List of Karpenter Helm set values"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "karpenter_resources_helm_values" {
  description = "List of Karpenter Resources Helm values"
  type        = list(string)
  default     = []
}

variable "karpenter_resources_helm_set" {
  description = "List of Karpenter Resources Helm set values"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# TODO: Remove when the network module is deprecated
variable "karpenter" {
  description = "[Deprecated] Karpenter configurations"
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

variable "enable_reloader" {
  description = "Enable Reloader"
  type        = bool
  default     = true
}

variable "reloader" {
  description = "Reloader configurations"
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
  default     = false
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
  default     = false
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
  default     = false
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

variable "enable_argocd" {
  description = "Enable Argo CD"
  type        = bool
  default     = false
}

variable "argocd" {
  description = "Argo CD configurations"
  type = object({
    # Hub specific
    enable_hub        = optional(bool, false)
    namespace         = optional(string, "argocd")
    hub_iam_role_name = optional(string, "argocd-controller")

    helm_values = optional(list(string), [])
    helm_set = optional(list(object({
      name  = string
      value = string
    })), [])

    # Spoke specific
    enable_spoke = optional(bool, false)

    hub_iam_role_arn  = optional(string, null)
    hub_iam_role_arns = optional(list(string), null)

    # Common
    tags = optional(map(string), {})
  })
  default = {}
}
