variable "name_prefix" { type = string }
variable "scope" {
  type        = string
  description = "REGIONAL (ALB/API GW) or CLOUDFRONT."
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}
variable "rate_limit" {
  type    = number
  default = 2000
}
variable "tags" {
  type    = map(string)
  default = {}
}
