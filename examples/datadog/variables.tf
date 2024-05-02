variable "region" {
  description = "The region to deploy the platform"
  type        = string
  default     = "eu-central-1"
}

variable "datadog_site" {
  description = "The Datadog site to use"
  type        = string
  default     = "datadoghq.eu"
}

variable "datadog_api_key" {
  description = "The Datadog API key"
  type        = string
}
variable "datadog_app_key" {
  description = "The Datadog APP key"
  type        = string
}
