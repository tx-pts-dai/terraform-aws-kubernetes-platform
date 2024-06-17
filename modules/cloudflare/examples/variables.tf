variable "zones" {
  description = "A map of route53 zones to create"
  type = map(object({
    comment = optional(string, "")
  }))
  default = {}
}
