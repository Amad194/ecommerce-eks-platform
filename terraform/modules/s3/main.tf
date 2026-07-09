###############################################################################
# S3 module — two buckets:
#   * static  -> static assets served through CloudFront (OAC-locked)
#   * backups -> database dumps / media backups (versioned, lifecycle to IA)
###############################################################################

locals {
  buckets = {
    static  = "${var.name_prefix}-static-assets"
    backups = "${var.name_prefix}-backups"
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets
  bucket   = each.value
  tags     = merge(var.tags, { Purpose = each.key })
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.this["backups"].id
  rule {
    id     = "transition-and-expire"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

# NOTE: the CloudFront OAC read policy for the static bucket is attached in the
# root module (aws_s3_bucket_policy.static_cf) to avoid an s3 <-> cloudfront
# module cycle.
