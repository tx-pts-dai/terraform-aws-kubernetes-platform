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
  description = "Kubernetes version for the EKS cluster (e.g., \"1.36\")"
  type        = string
  default     = "1.36"
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
    - iam_role_additional_policies: Additional IAM policy ARNs to attach to the cluster IAM role (default: []). This is now required by auto_mode.
    - authentication_mode: EKS auth mode (default: "API"). When adopting a cluster still on the aws-auth ConfigMap, set "API_AND_CONFIG_MAP" until every principal is reproduced as an access entry, then move to "API".
    - encryption_config: Cluster secrets-encryption config (default: {} = encrypt secrets). Set to null to adopt a cluster with no encryption without enabling it (enabling is irreversible).
    - create_kms_key: Whether to create a KMS key for cluster encryption (default: true). Set false together with encryption_config = null to skip encryption, or with encryption_config.provider_key_arn to reuse an existing key.

  Core addon settings (vpc_cni, kube_proxy, eks_pod_identity_agent):
    - configuration_values: JSON string of addon configuration (merged with defaults for vpc-cni). The vpc-cni default enables network policy enforcement (`enableNetworkPolicy = "true"`, ignored in pure EKS Auto Mode where the module does not manage the vpc-cni addon) in `env.NETWORK_POLICY_ENFORCING_MODE = "standard"` mode, so new pods stay allow-all until their NetworkPolicy is applied rather than deny-all (`"strict"` mode, which requires an explicit policy for every endpoint including CoreDNS). Pass any key here, including enableNetworkPolicy or env.NETWORK_POLICY_ENFORCING_MODE, to override it.

  Example:
    eks = {
      cluster_endpoint_public_access = false
      vpc_cni = {
        configuration_values = jsonencode({
          enableNetworkPolicy = "false"
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
# EKS Auto Mode
# See docs/auto-mode-migration.md for the full self-managed <-> Auto Mode migration path.
variable "enable_auto_mode" {
  description = "Enable EKS Auto Mode. AWS manages compute (built-in Karpenter), block storage, load balancing and core networking. Can be combined with enable_karpenter to run both compute stacks side-by-side during a migration."
  type        = bool
  default     = false
}

variable "auto_mode" {
  description = <<-EOT
  EKS Auto Mode configuration. Only used when `enable_auto_mode = true`.
    - builtin_node_pools: List of AWS-managed node pools to enable (e.g. ["general-purpose", "system"]). Leave empty ([]) to only use your own NodePools/NodeClasses.
    - node_iam_role_additional_policies: Additional IAM policy ARNs to attach to the Auto Mode node role, keyed by an arbitrary name.
    - default_node_pool_taints: Taints applied to the auto-generated `default` NodePool (ignored when you pass your own auto_mode_node_pools). Use this during a migration so existing workloads do not schedule onto Auto Mode nodes until they tolerate the taint.
    - discover_karpenter_subnets: Controls how the auto-generated `default` NodeClass finds subnets. When true, it discovers them by tag (see subnet_discovery_tags) — by default the SAME dedicated subnets as the self-managed Karpenter stack (the "same network, different NodePools/taints" migration path). When false, it selects var.vpc.private_subnets by ID. Defaults to null, which resolves to enable_karpenter: shared subnets while the Karpenter stack runs, private subnets in pure Auto Mode. Ignored when you pass your own auto_mode_node_classes.
    - subnet_discovery_tags: Tags the `default` NodeClass matches when discover_karpenter_subnets is true. Defaults to { "karpenter.sh/discovery" = <cluster-name> } (the tag the module puts on its own dedicated Karpenter subnets). Override it to match a customized Karpenter discovery tag — e.g. { "karpenter.sh/discovery" = "shared" } when Karpenter is pointed at pre-existing subnets via karpenter_resources_helm_set.
  EOT
  type = object({
    builtin_node_pools                = optional(list(string), [])
    node_iam_role_additional_policies = optional(map(string), {})
    default_node_pool_taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
    discover_karpenter_subnets = optional(bool, null)
    subnet_discovery_tags      = optional(map(string), null)
  })
  default = {}

  validation {
    # Tag discovery with the DEFAULT tag targets the module's own Karpenter
    # subnets, which only exist while the Karpenter stack runs. Custom
    # subnet_discovery_tags point at subnets the caller manages, so they are
    # allowed without the Karpenter stack.
    condition     = var.auto_mode.discover_karpenter_subnets != true || var.enable_karpenter || var.auto_mode.subnet_discovery_tags != null
    error_message = "auto_mode.discover_karpenter_subnets = true requires either enable_karpenter = true (to discover the module's karpenter.sh/discovery subnets) or auto_mode.subnet_discovery_tags set to tags on subnets you manage yourself."
  }
}

variable "auto_mode_node_classes" {
  description = <<-EOT
  Map of EKS Auto Mode NodeClass resources to apply (apiVersion `eks.amazonaws.com/v1`). The map key is the NodeClass name and the value is its `spec`.
  Only used when `enable_auto_mode = true`. When left empty, a `default` NodeClass is created that targets the cluster private subnets and primary security group and uses the Auto Mode node IAM role.
  EOT
  type        = any
  default     = {}
}

variable "auto_mode_node_pools" {
  description = <<-EOT
  Map of Karpenter NodePool resources to apply (apiVersion `karpenter.sh/v1`). The map key is the NodePool name and the value is its `spec`.
  Only used when `enable_auto_mode = true`. When left empty, a `default` NodePool referencing the `default` NodeClass is created.
  EOT
  type        = any
  default     = {}
}

variable "enable_self_managed_ebs_csi" {
  description = "Create the self-managed EBS CSI driver (addon, IRSA and pod-identity role). Defaults to enabled unless Auto Mode is on. Set to true to keep it running alongside Auto Mode's managed EBS CSI during a storage migration, or false to drop it."
  type        = bool
  default     = null
}

variable "enable_self_managed_lb_controller" {
  description = "Create the IAM pod-identity role for the self-managed AWS Load Balancer Controller. Defaults to enabled unless Auto Mode is on. Set to true to keep it alongside Auto Mode's built-in load balancing during a migration, or false to drop it."
  type        = bool
  default     = null
}

################################################################################
# Core Addons - Installed by default
# For compatibility with older versions of the module, the karpenter variable is optional
variable "enable_karpenter" {
  description = "Enable the self-managed Karpenter stack (controller, Helm releases, IRSA, subnets, security group, Fargate profile). Independent of enable_auto_mode: keep both enabled to run them side-by-side during a migration. At least one of enable_karpenter / enable_auto_mode must be true or the cluster has no compute."
  type        = bool
  default     = true

  validation {
    condition     = var.enable_karpenter || var.enable_auto_mode
    error_message = "At least one of enable_karpenter or enable_auto_mode must be true, otherwise the cluster has no compute."
  }
}

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

variable "enable_efs_csi_driver" {
  description = "Enable the aws-efs-csi-driver add-on (classic Amazon EFS and Amazon S3 Files storage) and its controller/node Pod Identity roles"
  type        = bool
  default     = true
}

################################################################################
# Additional Addons - Not installed by default

variable "enable_kubecost" {
  description = "Enable the kubecost_kubecost EKS add-on. Requires subscribing to Kubecost in AWS Marketplace for this account first, or addon creation fails."
  type        = bool
  default     = false
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

    # Spoke specific
    enable_spoke = optional(bool, false)

    hub_iam_role_arn  = optional(string, null)
    hub_iam_role_arns = optional(list(string), null)

    # Common
    tags = optional(map(string), {})
  })
  default = {}
}

variable "enable_argocd_capability" {
  description = "Enable the AWS-managed Argo CD EKS capability. Mutually exclusive with enable_argocd (self-managed Argo CD). Requires IAM Identity Center (auto-discovered, or set argocd_capability.idc_instance_arn)."
  type        = bool
  default     = false

  validation {
    condition     = !(var.enable_argocd_capability && var.enable_argocd)
    error_message = "enable_argocd_capability (managed Argo CD) and enable_argocd (self-managed Argo CD) are mutually exclusive; enable at most one."
  }
}

variable "argocd_capability" {
  description = <<-EOT
  Configuration for the AWS-managed Argo CD EKS capability. Only used when `enable_argocd_capability = true`.
    - idc_instance_arn: IAM Identity Center instance ARN. Leave null to auto-discover the account/org instance via the aws_ssoadmin_instances data source (requires sso:ListInstances).
    - idc_region: Region of the Identity Center instance (defaults to the provider region).
    - namespace: Kubernetes namespace for Argo CD (default "argocd").
    - rbac_role_mapping: Maps Identity Center users/groups to Argo CD roles (ADMIN, EDITOR, VIEWER).
    - vpc_endpoint_ids: VPC endpoint IDs for private access. When set, the public endpoint is BLOCKED and Argo CD is reachable only through these VPC endpoints. Leave empty for a public endpoint.
    - iam_policy_statements: Extra IAM policy statements to attach to the capability role (e.g. ECR read for image reflection).
  EOT
  type = object({
    idc_instance_arn = optional(string)
    idc_region       = optional(string)
    namespace        = optional(string, "argocd")
    rbac_role_mapping = optional(list(object({
      role = string
      identity = list(object({
        id   = string
        type = string
      }))
    })), [])
    vpc_endpoint_ids = optional(list(string), [])
    iam_policy_statements = optional(map(object({
      sid       = optional(string)
      actions   = optional(list(string))
      resources = optional(list(string))
      effect    = optional(string)
    })), {})
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
