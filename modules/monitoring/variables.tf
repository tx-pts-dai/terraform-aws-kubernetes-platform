variable "tags" {
  description = "A map of tags to add to the resources"
  type        = map(string)
  default     = {}
}

# variable "create" {
#   description = "Controls if resources should be created (affects nearly all resources)"
#   type        = bool
#   default     = true
# }

variable "fluent_operator" {
  description = "Map of values to pass to the Fluent Operator Helm chart"
  type        = any
  default     = {}
}