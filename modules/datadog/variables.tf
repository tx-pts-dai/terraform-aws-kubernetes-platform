variable "namespace" {
  description = "Namespace for Datadog resources"
  type        = string
  default     = "monitoring"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "environment" {
  description = "Name of the environment"
  type        = string
}

variable "datadog_operator" {
  description = "Datadog Operator configurations"
  type        = any
  default     = {}
}

variable "datadog_agent" {
  description = "Datadog Agent configurations"
  type        = any
  default     = {}
}

variable "datadog_secret" {
  description = "Name of the datadog secret in Secrets Manager"
  type        = string
}

variable "datadog_agent_version_fargate" {
  description = "Version of the datadog agent injected in Fargate"
  type        = string
  default     = "7.57.2" # github-releases/DataDog/datadog-agent"
}

variable "product_name" {
  description = "Value of the product tag added to all metrics and logs sent to datadog"
  type        = string
}
