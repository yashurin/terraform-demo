output "bucket_name" {
  description = "Private site bucket."
  value       = module.site.bucket_name
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name."
  value       = module.site.cloudfront_domain_name
}

output "cloudfront_url" {
  description = "HTTPS URL for this environment."
  value       = module.site.cloudfront_url
}

output "distribution_id" {
  description = "CloudFront distribution id."
  value       = module.site.distribution_id
}
