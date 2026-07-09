variable "namespace" {
  type    = string
  default = "argocd"
}
variable "chart_version" {
  type    = string
  default = "7.6.12"
}
variable "domain_name" { type = string }
variable "gitops_repo_url" {
  type        = string
  description = "URL of THIS repository — Argo CD reads charts/manifests from it."
}
variable "target_revision" {
  type    = string
  default = "HEAD"
}
variable "expose_ingress" {
  type        = bool
  description = "Expose the Argo CD UI via an nginx Ingress at argocd.<domain>."
  default     = true
}
