output "zones" {
  description = "A map of route53 zones"
  value       = module.route53_zones
}

output "cloudflare_records" {
  description = "A map of cloudflare records"
  value       = module.cloudflare
}
