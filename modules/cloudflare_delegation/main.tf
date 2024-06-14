locals {
  domain_split     = split(".", var.domain_name)
  top_level_domain = join(".", slice(local.domain_split, length(local.domain_split) - 2, length(local.domain_split)))
}

data "cloudflare_zone" "this" {
  account_id = var.account_id
  name       = local.top_level_domain
}

resource "cloudflare_record" "ns" {
  count   = length(var.name_servers)
  zone_id = data.cloudflare_zone.this.id
  name    = var.domain_name
  type    = "NS"
  value   = element(var.name_servers, count.index)
  ttl     = 3600
}
