variable "cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN (from the eks module)."
}

variable "hosted_zone_arns" {
  type        = list(string)
  description = "Route53 hosted zone ARNs ExternalDNS/cert-manager may manage."
  default     = ["arn:aws:route53:::hostedzone/*"]
}

variable "secrets_manager_arns" {
  type        = list(string)
  description = "Secrets Manager ARNs the External Secrets Operator may read."
  default     = ["arn:aws:secretsmanager:*:*:secret:ecommerce-prod/*"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
