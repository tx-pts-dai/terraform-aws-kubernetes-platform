# TODO: this is a private hosted zone for testing. Parametrize to deploy private and public routes
# TODO: Look into the limitations of private hosted zones

locals {
  zone_name = "${local.stack_name}.${var.base_domain}"
}

resource "aws_route53_zone" "private" {
  count = var.base_domain != "" ? 1 : 0

  name = local.zone_name

  vpc {
    vpc_id = local.vpc.vpc_id
  }
}
