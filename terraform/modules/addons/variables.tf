variable "cluster_name" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "domain_name" { type = string }
variable "acme_email" {
  type        = string
  description = "Contact email for Let's Encrypt registration."
}
variable "acm_certificate_arn" { type = string }

# IRSA role ARNs (from the irsa module)
variable "lb_controller_role_arn" { type = string }
variable "cluster_autoscaler_role_arn" { type = string }
variable "external_dns_role_arn" { type = string }
variable "cert_manager_role_arn" { type = string }
variable "external_secrets_role_arn" { type = string }

variable "versions" {
  description = "Pinned Helm chart versions for each add-on."
  type = object({
    metrics_server     = string
    lb_controller      = string
    cluster_autoscaler = string
    ingress_nginx      = string
    cert_manager       = string
    external_dns       = string
    external_secrets   = string
  })
  default = {
    metrics_server     = "3.12.2"
    lb_controller      = "1.8.1"
    cluster_autoscaler = "9.37.0"
    ingress_nginx      = "4.11.2"
    cert_manager       = "v1.15.3"
    external_dns       = "1.15.0"
    external_secrets   = "0.10.4"
  }
}
