locals {
  domain_split     = split(".", var.zone_name)
  remaining_parts  = slice(local.domain_split, 1, length(local.domain_split))
  top_level_domain = join(".", local.remaining_parts)
}

data "cloudflare_zone" "this" {
  filter = {
    account = {
      id = var.account_id
    }
    name = local.top_level_domain
  }
}

resource "cloudflare_dns_record" "ns" {
  count   = length(var.name_servers)
  zone_id = data.cloudflare_zone.this.zone_id
  name    = var.zone_name
  comment = var.comment
  type    = "NS"
  ttl     = 3600
  content = element(var.name_servers, count.index)
}
