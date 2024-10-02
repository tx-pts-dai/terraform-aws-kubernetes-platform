variable "records" {
  description = "List of records to create in Cloudflare"
  type = list(object({
    name    = string
    comment = optional(string, "Managed by Terraform")
    type    = string
    content = string
    ttl     = optional(number, 60)
  }))
}

variable "zone_name" {
  description = "The zone to create records in"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account id"
  type        = string
}
