variable "project" {
  type    = string
  default = "ecommerce"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# ---- Networking -------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnets" {
  type    = list(string)
  default = ["10.0.128.0/20", "10.0.144.0/20"]
}
variable "private_subnets" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20"]
}
variable "intra_subnets" {
  type    = list(string)
  default = ["10.0.240.0/24", "10.0.241.0/24"]
}
variable "single_nat_gateway" {
  type    = bool
  default = false
}

# ---- EKS --------------------------------------------------------------------
variable "cluster_version" {
  type    = string
  default = "1.30"
}
variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}
variable "node_min_size" {
  type    = number
  default = 2
}
variable "node_max_size" {
  type    = number
  default = 6
}
variable "node_desired_size" {
  type    = number
  default = 3
}

# ---- DNS / TLS --------------------------------------------------------------
variable "domain_name" {
  type        = string
  description = "Platform domain. Swap the placeholder for your real domain."
  default     = "example.com"
}
variable "create_hosted_zone" {
  type    = bool
  default = true
}
variable "acme_email" {
  type        = string
  description = "Email for Let's Encrypt registration."
  default     = "platform@example.com"
}

# ---- GitOps -----------------------------------------------------------------
variable "gitops_repo_url" {
  type        = string
  description = "HTTPS/SSH URL of THIS repository (Argo CD reads charts from it)."
  default     = "https://github.com/Amad194/ecommerce-eks-platform.git"
}
variable "gitops_target_revision" {
  type    = string
  default = "HEAD"
}

# ---- Data store sizing (override in tfvars for cost/scale) ------------------
variable "rds_instance_class" {
  type    = string
  default = "db.r6g.large"
}
variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}
variable "opensearch_instance_type" {
  type    = string
  default = "r6g.large.search"
}
variable "mq_instance_type" {
  type    = string
  default = "mq.m5.large"
}
variable "mq_deployment_mode" {
  type    = string
  default = "CLUSTER_MULTI_AZ"
}
