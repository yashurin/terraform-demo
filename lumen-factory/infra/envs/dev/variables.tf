variable "aws_region" {
  type        = string
  description = "Region for the site bucket and the default AWS provider."
  default     = "eu-west-1"
}

variable "project_name" {
  type        = string
  description = "Project slug. Keep this stable across dev and prod."
  default     = "lumen-factory"
}

variable "environment" {
  type        = string
  description = "Must stay dev in this root. Prod has its own folder."
  default     = "dev"
}

variable "price_class" {
  type        = string
  description = "CloudFront price class passed to the module."
  default     = "PriceClass_100"
}

variable "enable_custom_domain" {
  type        = bool
  description = "Off by default. See terraform.tfvars.example for the domain flags."
  default     = false
}

variable "domain_name" {
  type        = string
  description = "Custom hostname. Ignored while enable_custom_domain is false."
  default     = ""
}

variable "hosted_zone_id" {
  type        = string
  description = "Existing Route 53 zone id. Ignored while enable_custom_domain is false."
  default     = ""
}
