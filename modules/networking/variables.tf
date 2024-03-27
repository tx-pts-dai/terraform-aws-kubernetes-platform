variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "create_vpc" {
  description = "Create the VPC"
  type        = bool
  default     = null
}

variable "name" {
  description = "The stack name for the resources"
  type        = string
  default     = ""
}

variable "cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = ""
}

variable "max_azs" {
  description = "The maximum number of availability zones to use"
  type        = number
  default     = 3
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

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = ""
}

variable "karpenter" {
  description = "Map of Karpenter configurations"
  type        = any
  default     = {}
}