output "amqps_endpoint" {
  value = tolist(aws_mq_broker.this.instances[0].endpoints)[0]
}

output "console_url" {
  value = aws_mq_broker.this.instances[0].console_url
}

output "secret_arn" {
  value = aws_secretsmanager_secret.mq.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
