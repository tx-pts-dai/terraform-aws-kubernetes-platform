# move resource from V4 to V5 - TODO: to be removed in next major version (v1)
moved {
  from = cloudflare_record.ns
  to   = cloudflare_dns_record.ns
}
