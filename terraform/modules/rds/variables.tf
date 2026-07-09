variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" {
  type        = list(string)
  description = "Intra subnets for the DB subnet group."
}
variable "allowed_security_group_ids" {
  type        = list(string)
  description = "SGs allowed to reach MySQL (EKS node SG)."
}
variable "engine_version" {
  type    = string
  default = "8.0"
}
variable "instance_class" {
  type    = string
  default = "db.r6g.large"
}
variable "allocated_storage" {
  type    = number
  default = 100
}
variable "max_allocated_storage" {
  type    = number
  default = 500
}
variable "db_name" {
  type    = string
  default = "magento"
}
variable "master_username" {
  type    = string
  default = "admin"
}
variable "backup_retention_period" {
  type    = number
  default = 14
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
