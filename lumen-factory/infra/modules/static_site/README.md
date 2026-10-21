# Module `static_site`

Creates one private S3 bucket, uploads a static directory, and puts CloudFront in front of it with origin access control. A custom domain is optional and off unless the caller sets the flag.

The bucket is not a public website. `block_public_acls`, `block_public_policy`, `ignore_public_acls`, and `restrict_public_buckets` are all true. The bucket policy grants `s3:GetObject` to `cloudfront.amazonaws.com` only when the source ARN is this distribution. That grant is not anonymous, so the public access block does not reject it.

Provider configuration does not live in this module. The caller passes the default AWS provider and an alias named `aws.us_east_1`. ACM resources use that alias and are created only when `enable_custom_domain` is true.

## Inputs

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `project_name` | string | — | Lowercase slug, 3–32 characters. |
| `environment` | string | — | `dev`, `staging`, or `prod`. |
| `aws_region` | string | — | Region of the bucket. Documented on the distribution comment. ACM does not use it. |
| `source_dir` | string | — | Directory that contains `index.html`. Run `make build` first. |
| `price_class` | string | `PriceClass_100` | `PriceClass_100`, `PriceClass_200`, or `PriceClass_All`. |
| `enable_custom_domain` | bool | `false` | Gates ACM and Route 53. |
| `domain_name` | string | `""` | Required with the flag. |
| `hosted_zone_id` | string | `""` | An existing zone. This module does not create one. |
| `default_tags` | map(string) | — | Applied to the bucket, distribution, and certificate. |

## Outputs

| Name | Meaning |
| --- | --- |
| `bucket_name` | Private bucket. |
| `cloudfront_domain_name` | `dxxxx.cloudfront.net`. |
| `cloudfront_url` | `https://` plus that domain. |
| `distribution_id` | Id for `aws cloudfront create-invalidation`. |

## Example

```hcl
module "site" {
  source = "../../modules/static_site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name         = "lumen-factory"
  environment          = "dev"
  aws_region           = "eu-west-1"
  source_dir           = abspath("${path.root}/../../../app/dist")
  price_class          = "PriceClass_100"
  enable_custom_domain = false
  domain_name          = ""
  hosted_zone_id       = ""
  default_tags = {
    Project     = "lumen-factory"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

CloudFront caches with the managed CachingOptimized policy. After you change HTML, invalidate:

```bash
aws cloudfront create-invalidation \
  --distribution-id "$(terraform output -raw distribution_id)" \
  --paths "/*"
```

WAF and access logs are not in this module. Add them later behind a variable that defaults to false if you want them. A log bucket is a real ongoing cost.
