# Infrastructure

Terraform publishes `app/dist/` to a private S3 bucket and serves it through CloudFront. Dev and prod are separate roots. They call `modules/static_site`. Remote state lives in a bucket from `bootstrap/`.

Nothing in this directory has been applied for you.

## Cost

S3 and a quiet CloudFront distribution are usually cents. ACM certificates are free. DynamoDB on-demand for one lock table is tiny. This repo does not create a Route 53 hosted zone. A zone you already pay for is unaffected until you opt into a custom domain.

Destroy dev and prod when you stop for the day. Leave bootstrap until the project is over.

```bash
cd lumen-factory/infra/envs/dev
terraform destroy
```

Prod is a different directory. Destroying dev does not destroy prod.

```bash
cd lumen-factory/infra/envs/prod
terraform destroy
```

CloudFront deletion often takes 10 to 15 minutes. Terraform disables the distribution and then waits.

## Layout

```text
infra/
  bootstrap/                 # state bucket + lock table, local state
  modules/static_site/       # bucket, OAC, CloudFront, optional DNS
  envs/dev/                  # thin root, state key .../dev/terraform.tfstate
  envs/prod/                 # thin root, state key .../prod/terraform.tfstate
```

## First apply

Build the files, then bootstrap, then dev. Full bootstrap steps are in `bootstrap/README.md`.

```bash
cd lumen-factory
make build

cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# set a globally unique state_bucket_name
terraform init
terraform plan
terraform apply
terraform output state_bucket
terraform output lock_table

cd ../envs/dev
cp backend.hcl.example backend.hcl
# paste the bucket and the lock table
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Outputs to read after apply:

| Output | What it is |
| --- | --- |
| `bucket_name` | Private bucket. Not a public website. |
| `cloudfront_domain_name` | Hostname CloudFront assigned. |
| `cloudfront_url` | `https://` URL to open. |
| `distribution_id` | Id for cache invalidation. |

`terraform plan` with `enable_custom_domain` left false shows the bucket, the origin access control, the distribution, the private bucket policy, and one `aws_s3_object` per file. It does not show ACM or Route 53.

Prod, when you want it:

```bash
cd lumen-factory/infra/envs/prod
cp backend.hcl.example backend.hcl
# same bucket and lock table as dev, do not copy dev's tfvars
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform output cloudfront_url
```

From the repo root, after init has been done once in that env:

```bash
make plan-dev
make apply-dev
make destroy-dev
make plan-prod
make apply-prod
```

There is no `make destroy-prod`. Prod destroy is the explicit command above so it is harder to run by habit.

Never pass dev tfvars into the prod directory. `terraform apply -var-file=../dev/terraform.tfvars` from prod is the mistake this layout exists to prevent. Each root also refuses to plan if `environment` does not match the folder.

## Region and the certificate

The default region is `eu-west-1`. The site bucket is created there. A certificate attached to CloudFront must be in **us-east-1**. The env configures a second provider alias for that, and the module uses it only when `enable_custom_domain` is true. With the flag false, no certificate is requested.

To turn a domain on, edit that env's `terraform.tfvars` (copy the example first), set the flag, the name, and an existing hosted zone id, then plan again. Expect ACM and two alias records. Validation waits until DNS answers.

## After you change the HTML

CloudFront is on the managed CachingOptimized cache policy. A new apply uploads the objects. Viewers can still see the previous HTML until the cache expires or you invalidate.

```bash
cd lumen-factory/infra/envs/dev
aws cloudfront create-invalidation \
  --distribution-id "$(terraform output -raw distribution_id)" \
  --paths "/*"
```

## State commands worth running

```bash
terraform state list
terraform state show module.site.aws_s3_bucket.site
terraform state show module.site.aws_cloudfront_distribution.site
```

The console is a check. The state is the source of truth.

## Remote state

Backend blocks cannot take variables. The object key is written in `backend.tf`. The bucket name, region, and table come from `backend.hcl`, which is gitignored.

```bash
terraform init -backend-config=backend.hcl
```

Migrate a pre-existing local env state with:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

Point init at a corrected backend file without copying state:

```bash
terraform init -reconfigure -backend-config=backend.hcl
```

Do not commit `terraform.tfstate`. Do not delete the site bucket because a migrate failed.

## CI

Workflows live in `.github/workflows/`. The root README section "CI" lists the GitHub variables. Prod is not applied on push.

If you do not want the bootstrap OIDC resources, create the provider and the role by hand and use the same trust rules documented in `bootstrap/README.md`. Grant the role the same service list, not `AdministratorAccess`. Store the role ARN in the GitHub variable `AWS_ROLE_ARN`.

Static access keys are a fallback only. Prefer OIDC. If you must use keys, the step looks like this and the keys are secrets, not files in git:

```yaml
# Not recommended.
- uses: aws-actions/configure-aws-credentials@v6
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ vars.AWS_REGION }}
```

## Migration notes

This checkout's first apply creates `module.site`. There is nothing to move.

If you previously applied a flat stack from this same directory, with addresses like `aws_s3_bucket.site` and `aws_cloudfront_distribution.site` in the env root, paste the blocks below into that env's `main.tf` **before** the next plan. Terraform ignores a `moved` block whose old address is not in state. If the old address is in state, the move keeps the bucket name and avoids a replace.

A replace is unavoidable if the bucket name itself changes (new `random_id`, new `project_name`, or a bucket that was never in state). Say so in the plan: a new bucket and a new distribution, and the old ones destroyed at the end of apply. Read that plan before you approve it.

```hcl
moved {
  from = random_id.suffix
  to   = module.site.random_id.suffix
}

moved {
  from = aws_s3_bucket.site
  to   = module.site.aws_s3_bucket.site
}

moved {
  from = aws_s3_bucket_public_access_block.site
  to   = module.site.aws_s3_bucket_public_access_block.site
}

moved {
  from = aws_s3_bucket_ownership_controls.site
  to   = module.site.aws_s3_bucket_ownership_controls.site
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.site
  to   = module.site.aws_s3_bucket_server_side_encryption_configuration.site
}

moved {
  from = aws_s3_bucket_policy.site
  to   = module.site.aws_s3_bucket_policy.site
}

moved {
  from = aws_s3_object.files
  to   = module.site.aws_s3_object.files
}

moved {
  from = aws_cloudfront_origin_access_control.site
  to   = module.site.aws_cloudfront_origin_access_control.site
}

moved {
  from = aws_cloudfront_distribution.site
  to   = module.site.aws_cloudfront_distribution.site
}
```

Prompt 02's public website resources (`aws_s3_bucket_website_configuration`, a policy for `Principal *`) are not in the module. Removing them from state is a destroy of those extra resources only. The bucket can stay if its address is moved. The public URL stops working. That is the point of the CloudFront step.

## Troubleshooting

**S3 says the bucket name exists.** Pick a different `state_bucket_name`, or let the module's random suffix do that job for the site bucket. Do not turn off the public access block to "make the name work."

**CloudFront returns 403 or a blank XML error.** The usual cause is a bucket policy that does not match the distribution ARN, or a missing default root object. This module sets the root object to `index.html` and maps origin 403 and 404 to `/404.html`. Re-check `terraform state show module.site.aws_s3_bucket_policy.site` and confirm the condition value is the distribution ARN. Do not switch the bucket back to a public website to silence the 403.

**The page is stale.** Run the invalidation command above.

**`terraform init` asks for a bucket.** `backend.hcl` is missing or still says `REPLACE_WITH_STATE_BUCKET`. Apply bootstrap first.

**Plan wants to destroy the whole site after a refactor.** Stop. Compare addresses with `terraform state list`. Add `moved` blocks, or accept a documented replace. Do not apply a surprise destroy.
