###############################################################################
# Route53 module — public hosted zone for the platform domain.
# ExternalDNS (running in-cluster) manages the app records automatically;
# this module just owns the zone + apex/CDN alias plumbing.
###############################################################################

resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0
  name  = var.domain_name
  tags  = var.tags
}

data "aws_route53_zone" "existing" {
  count        = var.create_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id  = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  zone_arn = "arn:aws:route53:::hostedzone/${local.zone_id}"
}

# NOTE: the cdn.<domain> alias to CloudFront is created in the root module to
# avoid a module cycle (route53 -> acm -> cloudfront -> route53). ExternalDNS
# manages the per-app records (shop/api/admin) automatically in-cluster.
