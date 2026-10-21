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
      condition     = var.environment == "prod"
      error_message = "This root is prod. Refusing environment = \"${var.environment}\". Do not apply dev tfvars here."
    }
  }
}

# Same module as dev. Differences are variables, not a copy of the resources.
# price_class stays PriceClass_100 unless you change this root's tfvars.
# To add standard CloudFront logs later, extend the module behind a flag
# that defaults to false. Do not turn logging on just to see a bucket.
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
