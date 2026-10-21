variable "aws_region" {
  type        = string
  description = "Region for the site bucket and the default AWS provider."
  default     = "eu-west-1"
}

variable "project_name" {
  type        = string
  description = "Project slug. Keep this the same string you used in dev."
  default     = "lumen-factory"
}

variable "environment" {
  type        = string
  description = "Must stay prod in this root."
  default     = "prod"
}

variable "price_class" {
  type        = string
  description = "CloudFront price class. PriceClass_100 is enough for the lesson. A later change can set PriceClass_All here without forking the module. Leave access logging off; a log bucket is a separate cost."
  default     = "PriceClass_100"
}

variable "enable_custom_domain" {
  type        = bool
  description = "Still false by default. Prod is the environment most likely to turn this on, once a hosted zone exists."
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
