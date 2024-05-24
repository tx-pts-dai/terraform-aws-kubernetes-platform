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
