output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = var.db_name
}

output "secret_arn" {
  description = "Secrets Manager ARN holding host/port/user/password."
  value       = aws_secretsmanager_secret.db.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
