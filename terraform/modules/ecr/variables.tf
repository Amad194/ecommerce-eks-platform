variable "name_prefix" { type = string }
variable "repositories" {
  type        = list(string)
  description = "Service names to create repositories for."
  default     = ["frontend", "magento", "api", "microservices", "worker"]
}
variable "force_delete" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
