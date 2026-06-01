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

###################### Subnet Name overrides ######################
# When non-empty, these override the upstream module's default ${name}-${tier}-${az}
# pattern with explicit per-subnet Name tags. One entry per AZ, in az_count order.
# Use when importing a legacy VPC whose subnet Name tags must be preserved.

variable "public_subnet_names" {
  description = "Explicit Name tag values for public subnets, one per AZ. Empty list keeps upstream default naming."
  type        = list(string)
  default     = []
}

variable "private_subnet_names" {
  description = "Explicit Name tag values for private subnets, one per AZ. Empty list keeps upstream default naming."
  type        = list(string)
  default     = []
}

variable "intra_subnet_names" {
  description = "Explicit Name tag values for intra subnets, one per AZ. Empty list keeps upstream default naming."
  type        = list(string)
  default     = []
}

###################### Default resources ######################
# Whether to let the upstream module take management of the VPC's default
# Network ACL / Route Table / Security Group (resources AWS auto-creates
# with every VPC). Defaults true to preserve the upstream module's behavior
# of hardening these defaults. Set false when adopting a legacy VPC to avoid
# applying the module's opinionated rules to live defaults.

variable "manage_default_network_acl" {
  description = "Whether the upstream module manages the VPC's default Network ACL (rules + tags). Set false to leave the live default NACL untouched (recommended when importing an existing VPC)."
  type        = bool
  default     = true
}

variable "manage_default_route_table" {
  description = "Whether the upstream module manages the VPC's default Route Table (routes + tags). Set false to leave the live default RT untouched."
  type        = bool
  default     = true
}

variable "manage_default_security_group" {
  description = "Whether the upstream module manages the VPC's default Security Group (rules + tags). Set false to leave the live default SG untouched (in particular, preserves any existing 'allow all from self' rule)."
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
