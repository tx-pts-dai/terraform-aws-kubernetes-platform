data "cloudflare_zone" "this" {
  account_id = var.account_id
  name       = var.domain_name
}

resource "cloudflare_record" "ns" {
  count   = length(var.name_servers)
  zone_id = data.cloudflare_zone.this.id
  name    = var.domain_name
  type    = "NS"
  value   = element(var.name_servers, count.index)
  ttl     = 3600
}
