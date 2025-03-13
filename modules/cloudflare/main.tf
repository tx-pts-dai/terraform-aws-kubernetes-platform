locals {
  domain_split     = split(".", var.zone_name)
  remaining_parts  = slice(local.domain_split, 1, length(local.domain_split))
  top_level_domain = join(".", local.remaining_parts)
}

data "cloudflare_zone" "this" {
  filter = {
    name = local.top_level_domain
  }
}


resource "cloudflare_dns_record" "ns" {
  count   = length(var.name_servers)
  zone_id = data.cloudflare_zone.this.id
  name    = var.zone_name
  comment = var.comment
  type    = "NS"
  ttl     = 3600
  data = {
    value = element(var.name_servers, count.index)
  }
}
