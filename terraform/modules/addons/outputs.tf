output "ingress_nginx_namespace" {
  value = helm_release.ingress_nginx.namespace
}

output "cluster_issuer_name" {
  value = "letsencrypt-prod"
}

output "grafana_url" {
  value = "https://grafana.${var.domain_name}"
}

output "grafana_admin_password" {
  value     = random_password.grafana.result
  sensitive = true
}
