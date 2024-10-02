data "cloudflare_zone" "this" {
  account_id = var.account_id
  name       = var.zone_name
}

resource "cloudflare_record" "this" {
  for_each = { for idx, values in var.records : idx => values }

  zone_id = data.cloudflare_zone.this.id

  name    = each.value.name
  comment = each.value.comment
  type    = each.value.type
  content = each.value.content
  ttl     = each.value.ttl
}
