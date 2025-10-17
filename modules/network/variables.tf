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
    { elasticache = 26 },
    { redshift = 26 },
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

variable "secondary_cidr_blocks" {
  description = " List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool"
  type        = list(string)
  default     = []
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

###################### VPC Endpoints ######################
variable "create_vpc_endpoints" {
  description = "Whether to create VPC endpoints for ECR and S3"
  type        = bool
  default     = false
}

variable "enabled_vpc_endpoints_private_dns" {
  description = "Whether to enable private DNS for VPC endpoints"
  type        = bool
  default     = true
}
