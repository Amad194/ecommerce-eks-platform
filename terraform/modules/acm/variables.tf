variable "domain_name" { type = string }
variable "zone_id" {
  type        = string
  description = "Route53 zone ID used for DNS validation."
}
variable "tags" {
  type    = map(string)
  default = {}
}
