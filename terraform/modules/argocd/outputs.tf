output "namespace" {
  value = helm_release.argocd.namespace
}

output "server_url" {
  value = "https://argocd.${var.domain_name}"
}

output "initial_admin_secret_hint" {
  value = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
