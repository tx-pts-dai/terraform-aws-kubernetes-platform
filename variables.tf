variable "region" {
  description = "AWS region to use"
  type        = string
  default     = null
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

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster (e.g., \"1.34\")"
  type        = string
  default     = "1.34"
}

variable "eks" {
  description = <<-EOT
  Map of EKS configurations including cluster settings and core addon customization.

  Cluster settings:
    - cluster_endpoint_public_access: Enable public access to cluster endpoint (default: true)
    - cluster_endpoint_private_access: Enable private access to cluster endpoint (default: true)
    - enable_cluster_creator_admin_permissions: Grant admin permissions to cluster creator (default: false)
    - create_iam_role: Whether the module creates the cluster IAM role (default: true). Set to false to reuse an existing role, e.g. when adopting an existing cluster.
    - iam_role_arn: ARN of an existing cluster IAM role to use when create_iam_role is false.

  Core addon settings (vpc_cni, kube_proxy, eks_pod_identity_agent):
    - configuration_values: JSON string of addon configuration (merged with defaults for vpc-cni)

  Example:
    eks = {
      cluster_endpoint_public_access = false
      vpc_cni = {
        configuration_values = jsonencode({
          env = {
            ENABLE_PREFIX_DELEGATION = "true"
            WARM_PREFIX_TARGET       = "1"
          }
        })
      }
    }
  EOT
  type        = any
  default     = {}

  validation {
    condition     = try(var.eks.create_iam_role, true) || try(var.eks.iam_role_arn, null) != null
    error_message = "When eks.create_iam_role is false, eks.iam_role_arn must be set to the ARN of an existing cluster IAM role."
  }
}

variable "cluster_admins" {
  description = <<-EOT
  Map of IAM roles to add as cluster admins
    role_arn: ARN of the IAM role to add as cluster admin
    role_name: Name of the IAM role to add as cluster admin
    kubernetes_groups: List of Kubernetes groups to add the role to (default: ["system:masters"])

  role_arn and role_name are mutually exclusive, exactly one must be set.
  EOT
  type = map(object({
    role_arn          = optional(string)
    role_name         = optional(string)
    kubernetes_groups = optional(list(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.cluster_admins :
      (v.role_arn != null) != (v.role_name != null) # XOR - exactly one must be set
    ])
    error_message = "Each cluster admin must have either role_arn or role_name, not both."
  }
}

variable "access_entries" {
  description = <<-EOT
  Additional EKS access entries, passed through to the underlying EKS module and
  merged with the admin entries derived from cluster_admins / SSO discovery.

  Use this for non-admin principals — e.g. roles mapped to custom Kubernetes
  groups (read-only, operator) — which cluster_admins cannot express because it
  always attaches the AmazonEKSClusterAdminPolicy. Keys must not collide with
  cluster_admins keys or the reserved "sso_admin" key; on any collision the
  admin entry wins.

  Typed as `any` to accept the full EKS module access_entries schema (nested
  policy_associations etc.), but it must be a map. Each entry, e.g.:
    access_entries = {
      readonly = {
        principal_arn     = "arn:aws:iam::123456789012:role/AWSReservedSSO_ReadOnly_abc"
        kubernetes_groups = ["readonly"]
      }
    }
  EOT
  type        = any
  default     = {}

  validation {
    condition     = can(keys(var.access_entries))
    error_message = "access_entries must be a map of access entry objects."
  }

  validation {
    condition     = length(setintersection(keys(var.access_entries), concat(keys(var.cluster_admins), ["sso_admin"]))) == 0
    error_message = "access_entries keys must not collide with cluster_admins keys or the reserved \"sso_admin\" key."
  }
}

variable "enable_sso_admin_auto_discovery" {
  description = "Enable automatic discovery of SSO admin roles. When disabled, only explicitly defined cluster_admins are used."
  type        = bool
  default     = true
}

variable "enable_ecr_passthrough_policy" {
  description = "Enable the ECR pull-through cache policy for cluster nodes. This policy may grant additional ECR permissions, including automatic repository creation for pull-through cache repositories, and is not required for standard ECR image pulls."
  type        = bool
  default     = false
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
    type  = optional(string)
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
    type  = optional(string)
  }))
  default = []
}

variable "enable_fargate_fluentbit" {
  description = "Enable Fargate Fluentbit"
  type        = bool
  default     = true
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

    # Spoke specific
    enable_spoke = optional(bool, false)

    hub_iam_role_arn  = optional(string, null)
    hub_iam_role_arns = optional(list(string), null)

    # Common
    tags = optional(map(string), {})
  })
  default = {}
}

################################################################################
# EKS Capabilities
################################################################################

variable "enable_ack" {
  description = "Enable ACK (AWS Controllers for Kubernetes) EKS capability. Note: AdministratorAccess is attached by default. Use ack_iam_policy_arn to override with a least-privilege policy."
  type        = bool
  default     = true
}

variable "ack_iam_policy_arn" {
  description = "IAM policy ARN to attach to the ACK capability role. Defaults to AdministratorAccess if not specified."
  type        = string
  default     = null
}

################################################################################
# Kubernetes Access Control
################################################################################

variable "kubernetes_access_roles" {
  description = <<-EOT
    Map of reusable IAM roles that can be assumed by multiple principals.
    Creates standard roles that grant different levels of Kubernetes access.

    Supported predefined access_level values:
    - "view"         -> AmazonEKSViewPolicy (read-only)
    - "edit"         -> AmazonEKSEditPolicy (create/update resources)
    - "admin"        -> AmazonEKSClusterAdminPolicy (full admin)
    - "custom"       -> Use custom_policy_arns (list of policy ARNs)

    Example:
    {
      "readonly" = {
        controller_iam_role_arns = [
          "arn:aws:iam::123456789012:role/backstage-prod",
          "arn:aws:iam::123456789012:role/ai-agent"
        ]
        access_level = "view"           # Predefined: view, edit, admin, or custom
        scope        = "cluster"        # "cluster" or "namespace"
        namespaces   = []               # required if scope = "namespace"
      }
      "developer" = {
        controller_iam_role_arns = ["arn:aws:iam::123456789012:role/dev-team"]
        access_level = "edit"
        scope        = "namespace"
        namespaces   = ["development", "staging"]
      }
      "ops-admin" = {
        controller_iam_role_arns = ["arn:aws:iam::123456789012:role/ops-team"]
        access_level = "admin"
        scope        = "cluster"
      }
      "custom-access" = {
        controller_iam_role_arns = ["arn:aws:iam::123456789012:role/special-service"]
        access_level = "custom"
        custom_policy_arns = [
          "arn:aws:eks::aws:cluster-access-policy/MyCustomPolicy"
        ]
        scope = "cluster"
      }
    }

    This creates:
    - {cluster}-k8s-readonly (view access)
    - {cluster}-k8s-developer (edit access on dev/staging namespaces)
    - {cluster}-k8s-ops-admin (full admin access)
    - {cluster}-k8s-custom-access (custom policies)
  EOT
  type = map(object({
    controller_iam_role_arns = list(string)
    access_level             = string # "view", "edit", "admin", or "custom"
    scope                    = string # "cluster" or "namespace"
    namespaces               = optional(list(string), [])
    custom_policy_arns       = optional(list(string), [])
    external_id              = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.kubernetes_access_roles :
      contains(["view", "edit", "admin", "custom"], v.access_level)
    ])
    error_message = "access_level must be one of: view, edit, admin, custom"
  }

  validation {
    condition = alltrue([
      for k, v in var.kubernetes_access_roles :
      contains(["cluster", "namespace"], v.scope)
    ])
    error_message = "scope must be either 'cluster' or 'namespace'"
  }

  validation {
    condition = alltrue([
      for k, v in var.kubernetes_access_roles :
      v.scope == "namespace" ? length(v.namespaces) > 0 : true
    ])
    error_message = "namespaces must be provided when scope is 'namespace'"
  }

  validation {
    condition = alltrue([
      for k, v in var.kubernetes_access_roles :
      length(v.controller_iam_role_arns) > 0
    ])
    error_message = "At least one controller_iam_role_arns entry must be provided"
  }

  validation {
    condition = alltrue([
      for k, v in var.kubernetes_access_roles :
      v.access_level == "custom" ? length(lookup(v, "custom_policy_arns", [])) > 0 : true
    ])
    error_message = "custom_policy_arns must be provided when access_level is 'custom'"
  }
}
