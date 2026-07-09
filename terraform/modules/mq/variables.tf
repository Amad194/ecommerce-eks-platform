variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "allowed_security_group_ids" { type = list(string) }
variable "engine_version" {
  type    = string
  default = "3.13"
}
variable "instance_type" {
  type    = string
  default = "mq.m5.large"
}
variable "deployment_mode" {
  type        = string
  description = "SINGLE_INSTANCE (dev) or CLUSTER_MULTI_AZ (prod HA)."
  default     = "CLUSTER_MULTI_AZ"
}
variable "username" {
  type    = string
  default = "ecommerce"
}
variable "tags" {
  type    = map(string)
  default = {}
}
