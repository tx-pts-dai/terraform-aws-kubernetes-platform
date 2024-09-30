variable "create" {
  description = "Create the security group."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The VPC id to create the security group in."
  type        = string
}

variable "name" {
  type        = string
  description = "The name of the security group, this name must be unique within the VPC."
}

variable "description" {
  description = "The description of the security group."
  type        = string
  default     = ""
}

variable "ingress_rules" {
  description = "The ingress rules for the security group."
  type = map(object({
    type                     = string
    protocol                 = string
    from_port                = number
    to_port                  = number
    description              = optional(string)
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    prefix_list_ids          = optional(list(string))
    self                     = optional(bool)
    source_security_group_id = optional(string)
  }))
  default = {}
}

variable "egress_rules" {
  description = "The egress rules for the security group."
  type = map(object({
    type                     = string
    protocol                 = string
    from_port                = number
    to_port                  = number
    description              = optional(string)
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    prefix_list_ids          = optional(list(string))
    self                     = optional(bool)
    source_security_group_id = optional(string)
  }))
  default = {}
}
