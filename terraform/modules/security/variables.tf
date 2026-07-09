variable "name_prefix" { type = string }

variable "enable_guardduty" {
  type    = bool
  default = true
}
variable "enable_security_hub" {
  type    = bool
  default = true
}
variable "enable_inspector" {
  type    = bool
  default = true
}
variable "enable_cloudtrail" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
