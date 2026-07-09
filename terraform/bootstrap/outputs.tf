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

output "ci_role_arn" {
  description = "Set this as the AWS_TF_ROLE_ARN GitHub secret."
  value       = var.enable_github_oidc ? aws_iam_role.ci[0].arn : null
}

output "github_secrets_hint" {
  description = "GitHub secrets to configure for the Terraform pipeline."
  value = var.enable_github_oidc ? {
    AWS_TF_ROLE_ARN = aws_iam_role.ci[0].arn
    TF_STATE_BUCKET = aws_s3_bucket.state.id
  } : null
}
