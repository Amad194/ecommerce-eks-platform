###############################################################################
# CloudFront module — CDN in front of the S3 static-assets bucket.
# Uses Origin Access Control (OAC) so the bucket stays fully private, an ACM
# cert for TLS, and a WAF Web ACL (CLOUDFRONT scope, us-east-1).
###############################################################################

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name_prefix}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} static assets CDN"
  price_class         = "PriceClass_100"
  default_root_object = "index.html"
  aliases             = var.aliases
  web_acl_id          = var.web_acl_arn

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-static"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed CachingOptimized policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}
