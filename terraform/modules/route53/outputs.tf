output "zone_id" {
  value = local.zone_id
}

output "zone_arn" {
  value = local.zone_arn
}

output "name_servers" {
  description = "Delegate your registrar to these if the zone was created here."
  value       = var.create_zone ? aws_route53_zone.this[0].name_servers : []
}
