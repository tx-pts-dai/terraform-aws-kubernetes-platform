variable "region" {
  description = "AWS region to use"
  type        = string
  default     = null
}

variable "create_addons" {
  description = "Create the platform addons. if set to false, no addons will be created"
  type        = bool
  default     = true
}

variable "create_addon_roles" {
  description = "Create addon IRSA roles. If set to false, no addon roles will be created"
  type        = bool
  default     = true
}

variable "create_addon_pod_identity_roles" {
  description = "Create addon pod identities roles. If set to true, all roles will be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "The name of the platform, a timestamp will be appended to this name to make the stack_name. If not provided, the name of the directory will be used."
  type        = string
  default     = ""
}

variable "enable_timestamp_id" {
  description = "Disable the timestamp-based ID generation. When true, uses a static ID instead of timestamp."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  description = "VPC configurations"
  type = object({
    vpc_id          = string
    vpc_cidr        = string
    private_subnets = list(string)
    intra_subnets   = list(string)
  })
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

variable "enable_sso_admin_auto_discovery" {
  description = "Enable automatic discovery of SSO admin roles. When disabled, only explicitly defined cluster_admins are used."
  type        = bool
  default     = true
}

################################################################################
# Extra EKS Addons
################################################################################

variable "extra_cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`. Addons are created after karpenter resources"
  type        = any
  default     = {}
}

variable "extra_cluster_addons_timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster addons"
  type        = map(string)
  default     = {}
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

################################################################################
# Core Addons - Installed by default
# For compatibility with older versions of the module, the karpenter variable is optional
variable "karpenter" {
  description = "Karpenter configurations"
  type = object({
    subnet_cidrs = optional(list(string), [])
  })
  default = {}
}

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
# Additional Addons - Not installed by default

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
