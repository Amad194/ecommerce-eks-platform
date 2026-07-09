output "state_bucket" {
  description = "Name of the S3 bucket holding Terraform state. Put this in environments/prod/backend.tf."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "Name of the DynamoDB lock table. Put this in environments/prod/backend.tf."
  value       = aws_dynamodb_table.lock.name
}

output "region" {
  description = "Region the backend lives in."
  value       = var.region
}
