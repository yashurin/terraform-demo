locals {
  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "terraform_data" "env_guard" {
  lifecycle {
    precondition {
      condition     = var.environment == "dev"
      error_message = "This root is dev. Refusing environment = \"${var.environment}\". Do not apply prod tfvars here."
    }
  }
}

module "site" {
  source = "../../modules/static_site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  source_dir           = abspath("${path.root}/../../../app/dist")
  price_class          = var.price_class
  enable_custom_domain = var.enable_custom_domain
  domain_name          = var.domain_name
  hosted_zone_id       = var.hosted_zone_id
  default_tags         = local.default_tags
}
