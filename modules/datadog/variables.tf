variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "environment" {
  description = "Name of the environment"
  type        = string
}

variable "datadog_secret" {
  description = "Name of the datadog secret in Secrets Manager"
  type        = string
}

variable "product_name" {
  description = "Value of the product tag added to all metrics and logs sent to datadog"
  type        = string
}

variable "namespace" {
  description = "Namespace for Datadog resources"
  type        = string
  default     = "monitoring"
}

variable "datadog_operator_helm_version" {
  description = "Version of the datadog operator chart"
  type        = string
  default     = "2.16.0" # renovate: datasource=helm depName=datadog-operator registryUrl=https://helm.datadoghq.com
}

variable "datadog_operator_helm_values" {
  description = "List of Datadog Operator Helm values"
  type        = list(string)
  default     = []
}

variable "datadog_operator_helm_set" {
  description = "List of Datadog Operator Helm set values"
  type = list(object({
    name  = string
    value = string
    type  = optional(string)
  }))
  default = []
}

variable "datadog_agent_helm_values" {
  description = "List of Datadog Agent custom resource values"
  type        = list(string)
  default     = []
}

variable "datadog_agent_helm_set" {
  description = "List of Datadog Agent custom resource set values"
  type = list(object({
    name  = string
    value = string
    type  = optional(string)
  }))
  default = []
}
