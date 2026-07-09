output "repository_urls" {
  description = "Map of service name -> repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "registry_id" {
  value = values(aws_ecr_repository.this)[0].registry_id
}
