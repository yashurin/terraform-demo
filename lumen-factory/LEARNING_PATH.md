# Learning path

Each prompt added one idea. The tree below is the end of that sequence. Earlier shapes (an empty skeleton, then a public S3 website, then a flat CloudFront file) are not left behind as dead code.

| Step | Prompt | Where to look | What you can do |
| --- | --- | --- | --- |
| 00 | Charter | `README.md`, this file | Read the scope before changing anything. |
| 01 | Local site | `app/`, `Makefile`, `tests/` | `make dev`, `make build`, `make test`. Open Home, About, Workshop. |
| 02 | First publish | History only | A public S3 website endpoint and `website_url`. Prompt 03 removed that endpoint. |
| 03 | HTTPS | `infra/modules/static_site` | Private bucket, origin access control, CloudFront, optional domain flag. |
| 04 | Modules | `infra/envs/*`, `MODULES.md` | Env roots call the module. They do not contain the resources. |
| 05 | Remote state | `infra/bootstrap`, `backend.tf` | State bucket and DynamoDB lock. Env state keys are separate. |
| 06 | Two environments | `infra/envs/dev`, `infra/envs/prod` | Two applies, two CloudFront URLs, two state objects. |
| 07 | CI | `.github/workflows/` | Pull requests plan dev. Main applies dev. Prod is a manual dispatch. |
| Extra | CLI | `app/cli.py` | `lumen` shells out to the build and to Terraform. |
| Extra | OIDC | `infra/bootstrap/oidc.tf` | Off by default. Creates a role when you opt in. |

## Suggested order the first time you apply

1. Build the site and run the tests. No AWS yet.
2. Apply `infra/bootstrap` with local state.
3. Point `infra/envs/dev` at that bucket and apply dev.
4. Open `cloudfront_url`.
5. Apply prod only when dev looks right.
6. Turn on OIDC and the GitHub variables before you expect CI to plan.

## What changed between the S3 website and CloudFront

Prompt 02 created a world-readable bucket with website hosting. That URL was HTTP only. Prompt 03 replaced it:

- Public access stays blocked.
- There is no website endpoint.
- CloudFront reads the bucket with origin access control.
- The bucket policy allows `s3:GetObject` only for that distribution.

If a browser shows the old HTTP website URL, that host is gone. Use `cloudfront_url`.

## Folders, not workspaces

Dev and prod are directories. Each directory has its own backend key:

- `lumen-factory/dev/terraform.tfstate`
- `lumen-factory/prod/terraform.tfstate`

Terraform workspaces would keep both environments in one backend key and one set of variables, and it is easy to apply the wrong one. Folders make the boundary visible in `pwd`. Workspaces remain a reasonable tool when the split is temporary, such as a short-lived experiment in a single root. This lesson does not use them.
