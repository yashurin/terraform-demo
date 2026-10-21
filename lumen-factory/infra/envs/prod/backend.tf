# Partial backend. Values that differ per account live in backend.hcl.
# Key is fixed here so prod state never lands in the dev object.
terraform {
  backend "s3" {
    key     = "lumen-factory/prod/terraform.tfstate"
    encrypt = true
  }
}
