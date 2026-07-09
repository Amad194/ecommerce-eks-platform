output "endpoint" {
  value = aws_opensearch_domain.this.endpoint
}

output "secret_arn" {
  value = aws_secretsmanager_secret.os.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
