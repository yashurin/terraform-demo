# Lumen Factory

A site factory in one repo: a Python app builds static files, and Terraform publishes those files to AWS. You edit pages, run a build, apply an environment, and open an HTTPS URL.

"Site factory" here means that loop, not a multi-account platform. The product is the URL. The subject is Terraform.

## Learning sequence

1. **Local site.** Preview the pages and export `app/dist/`.
2. **S3.** The first historical publish was a public HTTP website. The code in this repo no longer does that.
3. **CloudFront.** A private bucket, origin access control, and HTTPS on the CloudFront domain.
4. **Modules.** `infra/envs/*` calls `infra/modules/static_site`.
5. **Remote state.** A bootstrap stack creates a state bucket and a DynamoDB lock.
6. **Environments.** Dev and prod are separate roots and separate state keys.
7. **CI.** Pull requests plan dev. Pushes to main apply dev. Prod is manual.

The map from those steps to folders is `LEARNING_PATH.md`. Why the module exists is `MODULES.md`.

## Non-goals for v1

- Kubernetes, ECS, RDS, VPC, NAT gateways
- Terraform provisioners
- A second programming language
- Hardcoded account ids or secrets in git
- WAF, CloudFront access logs, or a Route 53 zone created by this repo
- Terraform Cloud or a multi-account landing zone

## Destroy every night

Dev and prod cost little and still should not be left up out of habit. Destroy the environment you applied when you stop. Bootstrap (the state bucket and the lock table) can stay until you are finished with the whole project.

```bash
cd lumen-factory/infra/envs/dev
terraform destroy
```

Prod is separate:

```bash
cd lumen-factory/infra/envs/prod
terraform destroy
```

## Prerequisites

- An AWS account with a billing alarm
- AWS CLI credentials for a learning profile (`aws sts get-caller-identity`)
- Terraform >= 1.6 (workflows pin 1.16.6)
- Python 3.11+
- No domain name. The CloudFront hostname is enough. A custom domain is a flag, default off.

```bash
export AWS_PROFILE=your-learning-profile
export AWS_REGION=eu-west-1
aws sts get-caller-identity
```

## Run the site

```bash
cd lumen-factory
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
make dev          # http://127.0.0.1:8000
make build        # writes app/dist/
make test
```

Exact app commands are in `app/README.md`. Terraform commands are in `infra/README.md`. This README does not claim that any of them have been applied.

## Environments

| Environment | Directory | State key | What apply creates |
| --- | --- | --- | --- |
| dev | `infra/envs/dev` | `lumen-factory/dev/terraform.tfstate` | One private site and one CloudFront URL |
| prod | `infra/envs/prod` | `lumen-factory/prod/terraform.tfstate` | A second site and a second URL |

Both URLs show up as the `cloudfront_url` output of that directory. They are not known until you apply. Dev and prod share the module and must not share a tfvars file.

**Never apply prod with dev tfvars.** Do not pass `-var-file` across those directories. The prod root refuses a plan whose `environment` value is not `prod`.

Why these are folders instead of Terraform workspaces: the directory is the boundary you can see. Workspaces hide that split inside one state key. They are a fair choice for a short-lived experiment, and they are a poor fit for two sites you will destroy on different days. This lesson uses folders.

Makefile targets, after you have run `terraform init` in that env:

```bash
make plan-dev
make apply-dev
make destroy-dev
make plan-prod
make apply-prod
```

## Factory CLI

`lumen` is a teaching wrapper. It builds `app/dist/` and then runs Terraform. It is not a second deployment tool.

```bash
lumen build
lumen preview
lumen sites plan --env dev
lumen sites apply --env dev
lumen sites url --env dev
lumen sites destroy --env dev --yes
```

Prod destroy needs both flags:

```bash
lumen sites destroy --env prod --yes --i-mean-prod
```

`lumen --help` and `lumen sites <command> --help` describe each command.

## CI

Two workflows:

| File | When it runs | What it does |
| --- | --- | --- |
| `.github/workflows/terraform-dev.yml` | Pull request touching `app/**`, `infra/**`, the Makefile, `pyproject.toml`, or the workflows | Builds the site, `terraform fmt -check`, init, validate dev and prod, `terraform plan` for dev, uploads `tfplan-dev` |
| `.github/workflows/terraform-dev-apply.yml` | Push to `main` on those paths, or **Run workflow** | Builds the site and applies. A push applies **dev only**. Prod runs only when you dispatch the workflow and choose `prod`. |

A pull request from this repo should show the plan in the job log and attach the `tfplan-dev` artifact. The apply on main does not reuse that artifact. It applies the code on the branch. Fork pull requests will fail OIDC, because the token subject is the fork. That is expected.

Concurrency groups:

- `lumen-factory-plan-dev-<ref>` cancels an older plan when a new one starts.
- `lumen-factory-apply-<env>` does not cancel. A second apply for the same env waits, so two applies cannot write state together.

Terraform in CI is 1.16.6. The working directory is `infra/envs/dev` or `infra/envs/prod`.

### GitHub configuration

Repository **variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Example | Used for |
| --- | --- | --- |
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/lumen-factory-github-actions` | OIDC role to assume |
| `AWS_REGION` | `eu-west-1` | AWS region and the state backend region |
| `TF_STATE_BUCKET` | the `state_bucket` output | Remote state bucket |
| `TF_LOCK_TABLE` | `lumen-factory-tf-locks` | DynamoDB lock table |

No long-lived AWS keys belong in the repository. The workflows request `id-token: write` and assume the role with `aws-actions/configure-aws-credentials`.

Create the role with `infra/bootstrap` by setting `enable_github_oidc = true` (see `infra/bootstrap/README.md`), or create the same role by hand. `terraform output ci_role_arn` is the value of `AWS_ROLE_ARN`.

The role's trust policy must allow this repo's `sub` claims for `ref:refs/heads/main` and for `pull_request`. It must not be `AdministratorAccess`.

### Static keys

Not recommended. If OIDC is impossible in the account you were given, replace the configure-aws-credentials step with access keys stored as GitHub **secrets** `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The shape of that step is in `infra/README.md`. Do not commit the keys. Do not print them in a debug step.

## What a human does next

If the site builds and the tests pass, apply bootstrap, then dev, then open `cloudfront_url`. Details and the invalidation command are in `infra/README.md`.
