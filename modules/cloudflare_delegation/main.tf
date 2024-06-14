data "cloudflare_zone" "this" {
  account_id = var.account_id
  name       = "${split(".", var.domain_name)[1]}.${split(".", var.domain_name)[2]}" # Taking the TLD
}

resource "cloudflare_record" "ns" {
  count   = length(var.name_servers)
  zone_id = data.cloudflare_zone.this.id
  name    = var.domain_name
  type    = "NS"
  value   = element(var.name_servers, count.index)
  ttl     = 3600
}
