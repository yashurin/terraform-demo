# Bootstrap

This root creates the bucket and the lock table that `dev` and `prod` use for remote state. It does not create the website.

Bootstrap state stays **local**, in this directory, on purpose. The bucket cannot hold state until it exists. Putting bootstrap's own state into the bucket it just created is a second migration and a common way to lock yourself out. Leave this state on disk. Copy `terraform.tfstate` somewhere private if you care about recovering the bucket later. Never commit it.

Terraform Cloud is not used.

## Before you apply

Create a billing alarm in the AWS account. Then:

```bash
export AWS_PROFILE=your-learning-profile
export AWS_REGION=eu-west-1
aws sts get-caller-identity
```

You need permission to create an S3 bucket and a DynamoDB table. The same profile should later be allowed to read and write that bucket, because dev and prod use it too. This lesson does not create a second IAM user for that.

## 1. Apply bootstrap

```bash
cd lumen-factory/infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `state_bucket_name`. It must be globally unique. `lumen-factory-tfstate-` plus your name is a good pattern. Leave `enable_github_oidc` false until the site itself works.

```bash
terraform init
terraform plan
terraform apply
```

Read these outputs. You will paste them into the env backend files.

```bash
terraform output state_bucket
terraform output lock_table
```

`ci_role_arn` is null while OIDC is off.

## 2. Point an environment at the bucket

```bash
cd ../envs/dev
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` so `bucket` and `dynamodb_table` match the outputs. Leave the state key alone. `backend.tf` already sets `lumen-factory/dev/terraform.tfstate`. Prod uses `lumen-factory/prod/terraform.tfstate` in its own `backend.tf`.

```bash
terraform init -backend-config=backend.hcl
```

Repeat the copy for `infra/envs/prod` when you want a second state object. Use the same bucket and the same lock table.

## 3. If state is still local in an env

Use this only when `infra/envs/dev/terraform.tfstate` already exists because you applied once without the backend.

```bash
cd lumen-factory/infra/envs/dev
terraform init -migrate-state -backend-config=backend.hcl
```

Terraform asks to copy the local state into S3. Answer yes only if that local file is the state you mean to keep.

If init was already pointed at the wrong bucket or table:

```bash
terraform init -reconfigure -backend-config=backend.hcl
```

`-reconfigure` does not copy state. It only changes where the next command looks. Do not use it as a substitute for `-migrate-state` when the real state is still the local file.

After a successful migration, the local `terraform.tfstate` is no longer the source of truth. Do not delete the S3 **site** bucket to "reset" a backend problem. That bucket is the website. The state bucket is the other one.

## What not to put in the state bucket

Application HTML does not belong here. Site files go to the bucket the module creates, which is a different name and a different state entry (`aws_s3_bucket.site` inside the module).

## Destroy

Destroy dev and prod first. Destroy bootstrap last, and only when the project is over. An empty state bucket and an on-demand lock table are cheap enough to keep while you are still studying.

```bash
cd lumen-factory/infra/envs/dev
terraform destroy

cd ../../prod
terraform destroy

cd ../../bootstrap
terraform destroy
```

## GitHub OIDC (optional)

Off by default. When you set `enable_github_oidc = true`, this root creates:

- An IAM OIDC provider for `https://token.actions.githubusercontent.com`, unless you set `use_existing_github_oidc_provider = true`.
- A role named `lumen-factory-github-actions`.
- A role policy scoped to this project's site buckets, the state bucket, the lock table, CloudFront, ACM, and Route 53 record changes. It is not `AdministratorAccess`.

Trust policy intent: GitHub may assume the role only when the token audience is `sts.amazonaws.com` and the `sub` claim matches `repo:<org>/<repo>:<allowed ref>`. The default refs are `ref:refs/heads/main`, `ref:refs/heads/dev`, and `pull_request`.

Set the variables in `terraform.tfvars`:

```hcl
enable_github_oidc = true
github_org         = "your-github-org"
github_repo        = "lumen-factory"
```

Then:

```bash
terraform apply
terraform output ci_role_arn
```

Put that ARN in the GitHub repository variable `AWS_ROLE_ARN`. Do not put it in a secret. It is not a credential. The workflow also needs `AWS_REGION`, `TF_STATE_BUCKET`, and `TF_LOCK_TABLE`. See the root README section "CI".

### The provider already exists

An AWS account can only have one OIDC provider per URL. If apply stops with `EntityAlreadyExists` for `token.actions.githubusercontent.com`:

1. Set `use_existing_github_oidc_provider = true`.
2. Plan again. Terraform reads the provider instead of creating it.

Or import it and leave the flag false:

```bash
terraform import 'aws_iam_openid_connect_provider.github[0]' \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

Replace `ACCOUNT_ID` with your account. The thumbprint list is required by the API. AWS no longer uses those thumbprints to validate GitHub, but the resource still wants them.

### If you add a GitHub Environment

A job that sets `environment:` changes the OIDC `sub` claim to `repo:ORG/REPO:environment:NAME`. The default trust policy does not allow that. Add the suffix to `allowed_refs`, for example `environment:prod`, and apply bootstrap again. The workflows in this repo do not set a GitHub Environment, so the branch and pull request subjects are enough.
