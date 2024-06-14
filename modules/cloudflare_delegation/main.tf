resource "cloudflare_zone" "this" {
  account_id = var.account_id
  zone       = var.domain_name
}

resource "cloudflare_record" "ns" {
  count   = length(var.aws_route53_name_servers)
  zone_id = cloudflare_zone.this.id
  name    = var.domain_name
  type    = "NS"
  value   = element(var.aws_route53_name_servers, count.index)
  ttl     = 3600
}
