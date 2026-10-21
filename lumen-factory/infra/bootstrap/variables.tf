variable "aws_region" {
  type        = string
  description = "Region for the state bucket and the lock table."
  default     = "eu-west-1"
}

variable "project_name" {
  type        = string
  description = "Project slug. Site buckets are named <project>-<env>-<suffix>."
  default     = "lumen-factory"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, numbers, or hyphens."
  }
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique name for the Terraform state bucket. Example: lumen-factory-tfstate-yourname."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a lowercase S3 bucket name without dots."
  }
}

variable "enable_github_oidc" {
  type        = bool
  description = "Create the GitHub Actions OIDC provider (unless one already exists) and a deploy role. Off by default."
  default     = false
}

variable "use_existing_github_oidc_provider" {
  type        = bool
  description = "When true, look up the account's existing GitHub OIDC provider instead of creating one. Use this if apply fails with EntityAlreadyExists."
  default     = false
}

variable "github_org" {
  type        = string
  description = "GitHub organisation or user that owns the repo. Required only when enable_github_oidc is true."
  default     = ""
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name, without the owner. Required only when enable_github_oidc is true."
  default     = ""
}

variable "allowed_refs" {
  type        = list(string)
  description = "Suffixes of the GitHub OIDC sub claim, after repo:ORG/REPO:."
  default     = ["ref:refs/heads/main", "ref:refs/heads/dev", "pull_request"]
}
