output "lb_controller_role_arn" {
  value = module.lb_controller_irsa.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  value = module.cluster_autoscaler_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  value = module.external_dns_irsa.iam_role_arn
}

output "cert_manager_role_arn" {
  value = module.cert_manager_irsa.iam_role_arn
}

output "external_secrets_role_arn" {
  value = module.external_secrets_irsa.iam_role_arn
}
