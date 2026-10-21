# Optional GitHub Actions identity. Nothing here is created while
# enable_github_oidc is false. The policy is not AdministratorAccess.

locals {
  github_subs = [
    for suffix in var.allowed_refs : "repo:${var.github_org}/${var.github_repo}:${suffix}"
  ]
  oidc_provider_arn = var.enable_github_oidc ? (
    var.use_existing_github_oidc_provider
    ? data.aws_iam_openid_connect_provider.github[0].arn
    : aws_iam_openid_connect_provider.github[0].arn
  ) : null
  site_bucket_arns = flatten([
    for env in ["dev", "prod", "staging"] : [
      "arn:aws:s3:::${var.project_name}-${env}-*",
      "arn:aws:s3:::${var.project_name}-${env}-*/*",
    ]
  ])
}

resource "terraform_data" "oidc_inputs" {
  count = var.enable_github_oidc ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(var.github_org) > 0 && length(var.github_repo) > 0 && length(var.allowed_refs) > 0
      error_message = "github_org, github_repo, and allowed_refs are required when enable_github_oidc is true."
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc && !var.use_existing_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc && var.use_existing_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # sub looks like repo:ORG/REPO:ref:refs/heads/main
    # or repo:ORG/REPO:pull_request.
    # A GitHub Environment changes sub to repo:ORG/REPO:environment:NAME.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subs
    }
  }
}

data "aws_iam_policy_document" "github_deploy" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    sid       = "CreateAndListBuckets"
    actions   = ["s3:CreateBucket", "s3:ListAllMyBuckets", "s3:GetBucketLocation"]
    resources = ["*"]
  }

  statement {
    sid = "StateBucket"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
    ]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid = "StateObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid = "SiteBuckets"
    actions = [
      "s3:DeleteBucket",
      "s3:ListBucket",
      "s3:GetBucket*",
      "s3:PutBucket*",
      "s3:DeleteBucketPolicy",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
    ]
    resources = local.site_bucket_arns
  }

  statement {
    sid = "LockTable"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.locks.arn]
  }

  # CloudFront does not support resource-level permissions for these actions.
  statement {
    sid = "CloudFront"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:DeleteDistribution",
      "cloudfront:ListDistributions",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CertificateInUsEast1"
    actions = [
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:DeleteCertificate",
      "acm:ListCertificates",
      "acm:AddTagsToCertificate",
      "acm:ListTagsForCertificate",
      "acm:RemoveTagsFromCertificate",
    ]
    resources = ["*"]
  }

  # The hosted zone id is chosen later, in the env tfvars, so the role
  # cannot be pinned to one zone at bootstrap time. Tighten this after
  # you know the zone ARN.
  statement {
    sid = "DnsRecordsForOptionalDomain"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:ListHostedZones",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "github" {
  count = var.enable_github_oidc ? 1 : 0

  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_trust[0].json
}

resource "aws_iam_role_policy" "github" {
  count = var.enable_github_oidc ? 1 : 0

  name   = "${var.project_name}-deploy"
  role   = aws_iam_role.github[0].id
  policy = data.aws_iam_policy_document.github_deploy[0].json
}
