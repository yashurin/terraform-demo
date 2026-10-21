variable "project_name" {
  type        = string
  description = "Short project slug used in resource names. Lowercase, DNS-safe."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name baked into resource names and tags."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "Region of the site bucket. The env root provider uses this same region. ACM for a custom domain is always us-east-1 and does not follow this value."

  validation {
    condition     = length(var.aws_region) > 0
    error_message = "aws_region must be set."
  }
}

variable "source_dir" {
  type        = string
  description = "Absolute or module-relative path to the built static files (app/dist)."

  validation {
    condition     = length(var.source_dir) > 0
    error_message = "source_dir must point at the static build."
  }
}

variable "price_class" {
  type        = string
  description = "CloudFront price class. PriceClass_100 is the cheap default (US, Canada, Europe)."
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "enable_custom_domain" {
  type        = bool
  description = "When true, request an ACM certificate in us-east-1 and attach Route 53 alias records. When false, no ACM or Route 53 resources are created."
  default     = false
}

variable "domain_name" {
  type        = string
  description = "Custom domain, for example dev.example.com. Required only when enable_custom_domain is true."
  default     = ""
}

variable "hosted_zone_id" {
  type        = string
  description = "Route 53 hosted zone id that already exists. This module does not create the zone. Required only when enable_custom_domain is true."
  default     = ""
}

variable "default_tags" {
  type        = map(string)
  description = "Tags applied to the bucket, distribution, and certificate. The env root should pass Project, Environment, and ManagedBy."
}
