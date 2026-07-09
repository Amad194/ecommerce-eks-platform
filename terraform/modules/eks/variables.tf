variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes minor version."
  default     = "1.30"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets for worker nodes."
}

variable "intra_subnet_ids" {
  type        = list(string)
  description = "Subnets for the control-plane ENIs."
}

variable "endpoint_public_access" {
  type        = bool
  description = "Expose the API server publicly (restrict via CIDRs in prod)."
  default     = true
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

variable "tags" {
  type    = map(string)
  default = {}
}
