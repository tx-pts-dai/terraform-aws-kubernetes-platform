variable "environment" {
  description = "The environment this resource will be deployed in."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster to deploy"
  type        = string
}

variable "aws_ecrpublic_authorization_token" {
  description = "ECR public auth token"
  type = object({
    user_name = string
    password  = string
  })
}

variable "github_repo" {
  description = "Git repository name"
  type        = string
}

variable "sso_role_id" {
  description = "The id of the SSO role that will be allowed to run kubectl commands"
  type        = string
}

variable "cidr" {
  description = "cidr for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnets IP Ranges"
  type        = list(string)
  default     = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
}

variable "public_subnets" {
  description = "Public_Subnet IP Ranges"
  type        = list(string)
  default     = ["10.0.112.0/20", "10.0.128.0/20", "10.0.144.0/20"]
}
