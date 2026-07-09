###############################################################################
# Security & Compliance module — account/region-level detective controls:
#   GuardDuty · Security Hub (+ standards) · Inspector2 · CloudTrail
# Each control is independently toggleable. CloudTrail ships to a dedicated,
# encrypted, versioned, private S3 bucket with log-file validation.
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---- GuardDuty --------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  count                        = var.enable_guardduty ? 1 : 0
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs { enable = true }
    kubernetes {
      audit_logs { enable = true }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { enable = true }
      }
    }
  }

  tags = var.tags
}

# ---- Security Hub -----------------------------------------------------------
resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "foundational" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
  depends_on    = [aws_securityhub_account.this]
}

# ---- Inspector v2 (ECR image + EC2 host scanning) ---------------------------
resource "aws_inspector2_enabler" "this" {
  count          = var.enable_inspector ? 1 : 0
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2"]
}

# ---- CloudTrail -------------------------------------------------------------
locals {
  trail_bucket = "${var.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  trail_arn    = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.name_prefix}-trail"
}

resource "aws_s3_bucket" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = local.trail_bucket
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "trail" {
  count                   = var.enable_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.trail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration { days = 400 }
  }
}

data "aws_iam_policy_document" "trail" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail[0].arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  policy = data.aws_iam_policy_document.trail[0].json
}

resource "aws_cloudtrail" "this" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.trail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.trail]
}
