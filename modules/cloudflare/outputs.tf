output "records" {
  description = "A map of cloudflare records"
  value       = { for record in cloudflare_record.this : record.name => record.content... }
}
