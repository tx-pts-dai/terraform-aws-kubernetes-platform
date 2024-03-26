# TODO: this is a private hosted zone for testing. Parametrize to deploy private and public routes
resource "aws_route53_zone" "private" {
  name = "tamedia.ch"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}
