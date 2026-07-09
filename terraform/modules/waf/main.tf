###############################################################################
# WAF module — AWS WAFv2 Web ACL with AWS-managed rule groups + rate limiting.
# Instantiated twice: scope=REGIONAL (for the ALB) and scope=CLOUDFRONT.
###############################################################################

resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name_prefix}-${lower(var.scope)}-waf"
  scope = var.scope

  default_action {
    allow {}
  }

  # 1) Common rule set
  rule {
    name     = "AWSCommonRules"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }

  # 2) Known bad inputs
  rule {
    name     = "AWSKnownBadInputs"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "badinputs"
      sampled_requests_enabled   = true
    }
  }

  # 3) SQL injection
  rule {
    name     = "AWSSQLi"
    priority = 3
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sqli"
      sampled_requests_enabled   = true
    }
  }

  # 4) Rate limit per source IP
  rule {
    name     = "RateLimit"
    priority = 4
    action { block {} }
    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-${lower(var.scope)}"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}
