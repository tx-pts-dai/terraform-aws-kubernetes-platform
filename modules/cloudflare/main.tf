locals {
  domain_split     = split(".", var.zone_name)
  remaining_parts  = slice(local.domain_split, 1, length(local.domain_split))
  top_level_domain = join(".", local.remaining_parts)
}

data "cloudflare_zone" "this" {
  account_id = var.account_id
  name       = local.top_level_domain
}

resource "cloudflare_record" "ns" {
  for_each = toset(var.name_servers)

  zone_id = data.cloudflare_zone.this.id

  name    = var.zone_name
  comment = var.comment
  type    = "NS"
  content = each.value
  ttl     = 3600
}
