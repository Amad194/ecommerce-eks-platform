output "ingress_nginx_namespace" {
  value = helm_release.ingress_nginx.namespace
}

output "cluster_issuer_name" {
  value = "letsencrypt-prod"
}
