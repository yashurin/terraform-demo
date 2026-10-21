output "state_bucket" {
  description = "S3 bucket that stores env state. Copy this into backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "DynamoDB lock table. Copy this into backend.hcl."
  value       = aws_dynamodb_table.locks.name
}

output "ci_role_arn" {
  description = "Role ARN for GitHub Actions. Null while enable_github_oidc is false."
  value       = one(aws_iam_role.github[*].arn)
}
