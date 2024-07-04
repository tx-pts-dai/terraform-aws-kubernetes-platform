variable "zone_name" {
  description = "The domain name to delegate in Cloudflare"
  type        = string
}

variable "name_servers" {
  description = "List of name servers to delegate to Cloudflare"
  type        = list(string)
}

variable "account_id" {
  description = "Cloudflare account id"
  type        = string
}

variable "comment" {
  description = "Record comment"
  type        = string
  default     = "Managed by Terraform"
}
