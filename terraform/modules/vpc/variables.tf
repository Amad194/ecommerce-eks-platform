variable "name_prefix" {
  description = "Prefix for named resources, e.g. ecommerce-prod."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used for Kubernetes subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDRs for public (ALB/NLB) subnets."
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDRs for private (EKS node) subnets."
  type        = list(string)
}

variable "intra_subnets" {
  description = "CIDRs for intra (data store, no-NAT) subnets."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway (cheaper, dev) instead of one per AZ (HA, prod)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
