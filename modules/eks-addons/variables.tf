################################################################################
# Required Variables
################################################################################

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

################################################################################
# Optional Variables
################################################################################

variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster. Addon name can be the map key or set with `name`"
  type = map(object({
    create                      = optional(bool, true)
    name                        = optional(string)
    addon_version               = optional(string)
    configuration_values        = optional(string)
    most_recent                 = optional(bool, true)
    preserve                    = optional(bool, false)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    pod_identity_association = optional(list(object({
      role_arn        = string
      service_account = string
    })), [])
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }), {})
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "cluster_addons_timeouts" {
  description = "Default timeout values for addon resources"
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = {}
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
