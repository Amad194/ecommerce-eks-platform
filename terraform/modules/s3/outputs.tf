output "static_bucket_id" {
  value = aws_s3_bucket.this["static"].id
}

output "static_bucket_arn" {
  value = aws_s3_bucket.this["static"].arn
}

output "static_bucket_regional_domain_name" {
  value = aws_s3_bucket.this["static"].bucket_regional_domain_name
}

output "backups_bucket_id" {
  value = aws_s3_bucket.this["backups"].id
}

output "backups_bucket_arn" {
  value = aws_s3_bucket.this["backups"].arn
}
