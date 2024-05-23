variable "namespace" {
  description = "Namespace for Datadog resources"
  type        = string
  default     = "monitoring"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "datadog" {
  description = "Map of Datadog configurations"
  type        = any
  default     = {}
  # TODO: currently possible values. How to document them?
  # agent_api_key_name (default: cluster_name)
  # agent_app_key_name (default: cluster_name)
  # operator_chart_version
  # custom_resource_chart_version
}

variable "datadog_agent_values" {
  description = "Map of Datadog Agent values"
  type        = map(string)
  default = {
    "site"                      = "datadoghq.eu",
    "resources.requests.cpu"    = "10m",
    "resources.requests.memory" = "50Mi",
  }
}

variable "datadog_operator_values" {
  description = "Map of Datadog Operator values"
  type        = map(string)
  default     = {}
  # This needs to be a separated variable with type map(string) otherwise I could not do the merge in datadog.tf
}

variable "datadog_operator_sensitive_values" {
  description = "Map of Datadog Operator sensitive values"
  type        = map(string)
  default     = {}
}
