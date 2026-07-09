variable "project" {
  description = "Project name, used as a prefix for the state bucket and lock table."
  type        = string
  default     = "ecommerce"
}

variable "region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "enable_github_oidc" {
  description = "Create the GitHub OIDC provider + terraform-ci IAM role for the pipeline."
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "owner/repo allowed to assume the CI role via OIDC."
  type        = string
  default     = "Amad194/ecommerce-eks-platform"
}
