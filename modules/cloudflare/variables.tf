variable "zone_name" {
  description = "The domain name to delegate in Cloudflare"
  type        = string
}

variable "name_servers" {
  description = "Name servers to delegate to"
  type        = list(string)
}

variable "account_id" {
  description = "Cloudflare account id"
  type        = string
}
