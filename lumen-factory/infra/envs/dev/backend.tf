# Partial backend. Bucket, region, and lock table come from backend.hcl
# because a backend block cannot read variables.
# Key is fixed here so this root cannot write the prod state by mistake.
terraform {
  backend "s3" {
    key     = "lumen-factory/dev/terraform.tfstate"
    encrypt = true
  }
}
