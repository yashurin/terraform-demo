# Why the resources moved into a module

The first CloudFront stack lived as flat files in `infra/envs/dev`. That is a good place to learn what a bucket policy and a distribution look like. It is a bad place to grow a second environment. Copying those files into `prod` would fork every resource, and the two copies would drift the first time you fixed a bug in only one of them.

`infra/modules/static_site` is the shape of the site: bucket, origin access control, distribution, optional certificate, and the file upload. `infra/envs/dev` and `infra/envs/prod` are thin. They configure the AWS provider, select a state key, and call the module.

What stays outside the module, and why:

- **Provider blocks** stay in the env root. A module that creates its own provider is hard to reuse and fights provider aliases.
- **The us-east-1 alias** is configured in the env and passed in. CloudFront will not attach an ACM certificate from any other region. The module declares `configuration_aliases` so that requirement is visible.
- **The backend** stays in the env. Dev and prod must not share a state file, and a module cannot have its own backend.
- **Names** are built in the module as `lumen-factory-<env>-...` plus a random suffix so the bucket name is globally unique and stable for the life of that state.

A fresh `terraform plan` in this repo creates the module resources. It does not patch an older flat stack, because this checkout never applied the flat addresses. If you applied that earlier shape yourself, see "Migration notes" in `infra/README.md` before the next plan. Moving addresses is what avoids a destroy. Changing the bucket name is what forces a new bucket and a new distribution.

The mental model from here: **environments call modules**. Change behavior by adding a variable, not by editing a second copy of `aws_cloudfront_distribution`.
