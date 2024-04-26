variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "create_vpc" {
  description = "Create the VPC"
  type        = bool
  default     = true
}

variable "stack_name" {
  description = "The stack name for the resources"
  type        = string
}

variable "subnet_configs" {
  description = "List of networks objects with their name and size in bits. The order of the list should not change."
  type        = list(map(number))
  default = [
    { public = 24 },
    { private = 24 },
    { intra = 26 },
    { database = 26 },
    { redshift = 26 },
    { karpenter = 22 }
  ]
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
}

variable "cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateways"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway"
  type        = bool
  default     = true
}
