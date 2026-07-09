variable "name_prefix" { type = string }
variable "domain_name" {
  type        = string
  description = "OpenSearch domain name (<=28 chars, lowercase)."
  default     = "ecommerce-prod-os"
}
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "allowed_security_group_ids" { type = list(string) }
variable "engine_version" {
  type    = string
  default = "OpenSearch_2.13"
}
variable "instance_type" {
  type    = string
  default = "r6g.large.search"
}
variable "instance_count" {
  type    = number
  default = 2
}
variable "volume_size" {
  type    = number
  default = 100
}
variable "master_username" {
  type    = string
  default = "os-admin"
}
variable "tags" {
  type    = map(string)
  default = {}
}
