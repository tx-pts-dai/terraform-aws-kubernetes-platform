locals {
  primary_acm_domain = coalesce(var.acm_certificate.domain_name, var.base_domain)
  acm_san = var.acm_certificate.wildcard_certificates ? concat(
    ["*.${local.primary_acm_domain}"],
    [for host in var.acm_certificate.subject_alternative_names : "*.${host}.${local.primary_acm_domain}"],
    [for host in var.acm_certificate.subject_alternative_names : "${host}.${local.primary_acm_domain}"]
  ) : [for host in var.acm_certificate.subject_alternative_names : "${host}.${local.primary_acm_domain}"]
}

data "aws_route53_zone" "base_domain_zone" {
  count = var.acm_certificate.enabled ? 1 : 0

  name = local.primary_acm_domain
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.1"

  count = var.acm_certificate.enabled ? 1 : 0

  domain_name = local.primary_acm_domain
  zone_id     = data.aws_route53_zone.base_domain_zone[0].zone_id

  subject_alternative_names = local.acm_san

  validation_method   = "DNS"
  wait_for_validation = var.acm_certificate.wait_for_validation
}
