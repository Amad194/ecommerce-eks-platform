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
