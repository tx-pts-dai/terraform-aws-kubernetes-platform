variable "domain_name" {
  description = "The domain name to delegate in Cloudflare"
  type        = string
}

variable "aws_route53_name_servers" {
  description = "Route53 name servers"
  type        = list(string)
}

variable "account_id" {
  description = "Cloudflare account id"
  type        = string
}
