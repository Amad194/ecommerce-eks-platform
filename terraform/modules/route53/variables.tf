variable "domain_name" { type = string }
variable "create_zone" {
  type        = bool
  description = "Create a new hosted zone (true) or look up an existing one (false)."
  default     = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
