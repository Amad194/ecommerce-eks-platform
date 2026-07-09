# ---- Cluster ----------------------------------------------------------------
output "cluster_name" {
  value = module.eks.cluster_name
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "configure_kubectl" {
  description = "Run this to talk to the cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

# ---- Networking -------------------------------------------------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

# ---- Registry ---------------------------------------------------------------
output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

# ---- Data stores (endpoints only; secrets live in Secrets Manager) ----------
output "rds_endpoint" {
  value = module.rds.endpoint
}
output "redis_endpoint" {
  value = module.elasticache.configuration_endpoint
}
output "opensearch_endpoint" {
  value = module.opensearch.endpoint
}
output "rabbitmq_console_url" {
  value = module.mq.console_url
}

output "secret_arns" {
  description = "Secrets Manager ARNs the apps consume."
  value = {
    rds        = module.rds.secret_arn
    redis      = module.elasticache.secret_arn
    opensearch = module.opensearch.secret_arn
    rabbitmq   = module.mq.secret_arn
  }
}

# ---- Edge -------------------------------------------------------------------
output "cloudfront_domain_name" {
  value = module.cloudfront.domain_name
}
output "static_assets_bucket" {
  value = module.s3.static_bucket_id
}
output "backups_bucket" {
  value = module.s3.backups_bucket_id
}
output "route53_name_servers" {
  description = "Point your registrar here if the hosted zone was created by Terraform."
  value       = module.route53.name_servers
}
output "waf_regional_web_acl_arn" {
  description = "Attach to ALB ingresses via alb.ingress.kubernetes.io/wafv2-acl-arn."
  value       = module.waf_regional.web_acl_arn
}

# ---- Argo CD ----------------------------------------------------------------
output "argocd_url" {
  value = module.argocd.server_url
}
output "argocd_admin_password_cmd" {
  value = module.argocd.initial_admin_secret_hint
}
