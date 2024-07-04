variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "base_prefix" {
  description = "Base SSM namespace prefix for the parameters"
  type        = string
  default     = "infrastructure"
}

variable "stack_type" {
  description = "The type of terraform stack to be used in the namespace prefix. platform, network, account, shared"
  type        = string
  default     = ""
}

variable "stack_name" {
  description = "The name of the stack"
  type        = string
  default     = null
}

variable "stack_name_prefix" {
  description = "Filter all stacks that include this prefix in the name. "
  type        = string
  default     = ""
}

variable "parameters" {
  description = "Map of SSM parameters to create"
  type = map(object({
    name           = optional(string)
    type           = optional(string, "String")
    value          = optional(string)
    insecure_value = optional(string)
  }))
  default = {}
}

variable "lookup" {
  description = "List of parameters to Lookup"
  type        = list(any)
  default     = []
}
