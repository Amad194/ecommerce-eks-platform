output "configuration_endpoint" {
  value = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "secret_arn" {
  value = aws_secretsmanager_secret.redis.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
