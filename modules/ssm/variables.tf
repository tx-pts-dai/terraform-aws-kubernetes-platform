variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "base_prefix" {
  description = "Base SSM prefix for the platform parameters"
  type        = string
  default     = "/infrastructure"
}

variable "stack_type" {
  description = "The type of the terraform stack"
  type        = string
  default     = null
}
variable "stack_name" {
  description = "The name of the platform"
  type        = string
  default     = null
}

variable "parameters" {
  description = "Map of SSM parameters to create"
  type = map(object({
    name           = string
    type           = optional(string, "String")
    value          = optional(string)
    insecure_value = optional(string)
  }))
  default = {}
}

variable "latest" {
  description = "Set parameters in latest namespace"
  type        = bool
  default     = false
}

variable "stack_name_prefix" {
  description = "The prefix for the stack name"
  type        = string
  default     = ""
}
