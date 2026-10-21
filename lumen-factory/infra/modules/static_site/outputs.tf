output "bucket_name" {
  description = "Private S3 bucket that stores the static files."
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_domain_name" {
  description = "Distribution domain, for example d111111abcdef8.cloudfront.net."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_url" {
  description = "HTTPS URL to open in a browser."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution id, used for cache invalidation."
  value       = aws_cloudfront_distribution.site.id
}
