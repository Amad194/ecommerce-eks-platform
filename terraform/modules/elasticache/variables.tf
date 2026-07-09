variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "allowed_security_group_ids" { type = list(string) }
variable "engine_version" {
  type    = string
  default = "7.1"
}
variable "node_type" {
  type    = string
  default = "cache.r6g.large"
}
variable "num_node_groups" {
  type    = number
  default = 2
}
variable "replicas_per_node_group" {
  type    = number
  default = 1
}
variable "tags" {
  type    = map(string)
  default = {}
}
