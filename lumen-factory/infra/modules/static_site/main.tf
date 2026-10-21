# Private S3 origin + CloudFront Origin Access Control.
# Prompt 02 used a public website endpoint. Prompt 03 removed it.
# There is no aws_s3_bucket_website_configuration in this module.
# Access logging and WAF are omitted on purpose. Both add cost.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  origin_id   = "${local.name_prefix}-s3"
  site_files  = fileset(var.source_dir, "**")
  mime_types = {
    css   = "text/css; charset=utf-8"
    gif   = "image/gif"
    html  = "text/html; charset=utf-8"
    ico   = "image/x-icon"
    jpeg  = "image/jpeg"
    jpg   = "image/jpeg"
    js    = "text/javascript; charset=utf-8"
    json  = "application/json"
    png   = "image/png"
    svg   = "image/svg+xml"
    txt   = "text/plain; charset=utf-8"
    webp  = "image/webp"
    woff  = "font/woff"
    woff2 = "font/woff2"
  }
  # Splats stay valid when enable_custom_domain is false and the count is 0.
  certificate_arn = one(aws_acm_certificate_validation.site[*].certificate_arn)
  cert_validation = {
    for dvo in flatten(aws_acm_certificate.site[*].domain_validation_options) : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
}

resource "terraform_data" "dist_present" {
  lifecycle {
    precondition {
      condition     = fileexists("${var.source_dir}/index.html")
      error_message = "Missing ${var.source_dir}/index.html. From the repo root run: make build"
    }
  }
}

resource "terraform_data" "domain_guard" {
  lifecycle {
    precondition {
      condition     = !var.enable_custom_domain || (length(var.domain_name) > 0 && length(var.hosted_zone_id) > 0)
      error_message = "domain_name and hosted_zone_id are required when enable_custom_domain is true."
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4

  keepers = {
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_s3_bucket" "site" {
  bucket        = "${local.name_prefix}-${random_id.suffix.hex}"
  force_destroy = true
  tags          = var.default_tags
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.name_prefix}-oac"
  description                       = "Read ${local.name_prefix} objects from CloudFront only."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} static site in ${var.aws_region}. Standard logging is off."
  price_class         = var.price_class
  default_root_object = "index.html"
  aliases             = var.enable_custom_domain ? [var.domain_name] : []
  tags                = var.default_tags

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    # Managed cache policy CachingOptimized. HTML changes need an invalidation.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # A private bucket returns 403 for a missing key. Send both codes to the static 404 page.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !var.enable_custom_domain
    acm_certificate_arn            = local.certificate_arn
    ssl_support_method             = var.enable_custom_domain ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domain ? "TLSv1.2_2021" : null
  }
}

data "aws_iam_policy_document" "site" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_s3_object" "files" {
  for_each = local.site_files

  bucket        = aws_s3_bucket.site.id
  key           = each.value
  source        = "${var.source_dir}/${each.value}"
  etag          = filemd5("${var.source_dir}/${each.value}")
  content_type  = lookup(local.mime_types, lower(reverse(split(".", each.value))[0]), "application/octet-stream")
  cache_control = endswith(each.value, ".html") ? "public, max-age=60" : "public, max-age=86400"

  depends_on = [
    aws_s3_bucket_public_access_block.site,
    aws_s3_bucket_ownership_controls.site,
  ]
}

resource "aws_acm_certificate" "site" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = var.default_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.cert_validation

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "site" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.site[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "alias_a" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_aaaa" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
