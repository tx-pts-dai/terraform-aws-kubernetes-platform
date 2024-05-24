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
  description = "Object of Datadog configurations"
  type = object({
    agent_api_key_name            = optional(string)
    agent_app_key_name            = optional(string)
    operator_chart_version        = optional(string)
    custom_resource_chart_version = optional(string)
  })
  default = {}
}

variable "datadog_agent_helm_values" {
  description = "List of Datadog Agent custom resource values. https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "features.logs.enabled"
      value = "true"
    },
  ]
}

variable "datadog_operator_helm_values" {
  description = "List of Datadog Operator values"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "resources.requests.cpu"
      value = "10m"
    },
    {
      name  = "resources.requests.memory"
      value = "50Mi"
    },
  ]
}
