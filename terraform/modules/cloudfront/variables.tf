variable "name_prefix" { type = string }
variable "s3_bucket_regional_domain_name" { type = string }
variable "acm_certificate_arn" { type = string }
variable "web_acl_arn" {
  type    = string
  default = null
}
variable "aliases" {
  type    = list(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
