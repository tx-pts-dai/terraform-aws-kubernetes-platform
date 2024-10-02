variable "zones" {
  description = "A map of route53 zones to create"
  type = map(object({
    comment = optional(string, "")
  }))
  default = {
    "test.exmaple.ch" = {
      comment = "Managed by KAAS examples"
    }
  }
}
