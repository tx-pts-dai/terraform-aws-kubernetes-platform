locals {
  primary_acm_domain = (var.acm_certificate.domain_name != null) || (var.base_domain != null) ? coalesce(var.acm_certificate.domain_name, var.base_domain) : ""
  acm_san = concat(
    (var.acm_certificate.wildcard_certificates ? concat(
      ["*.${local.primary_acm_domain}"],
      [for host in var.acm_certificate.subject_alternative_names : "*.${host}.${local.primary_acm_domain}"]) : []
    ),
    (var.acm_certificate.prepend_stack_id ? [for host in var.acm_certificate.subject_alternative_names : "${local.id}-${host}.${local.primary_acm_domain}"] : []),
    [for host in var.acm_certificate.subject_alternative_names : "${host}.${local.primary_acm_domain}"]
  )
}

data "aws_route53_zone" "base_domain_zone" {
  count = var.create_addons && var.enable_acm_certificate ? 1 : 0

  name = local.primary_acm_domain
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.2.0"

  count = var.create_addons && var.enable_acm_certificate ? 1 : 0

  domain_name = local.primary_acm_domain
  zone_id     = data.aws_route53_zone.base_domain_zone[0].zone_id

  subject_alternative_names = local.acm_san

  validation_method   = "DNS"
  wait_for_validation = var.acm_certificate.wait_for_validation

  tags = local.tags
}
