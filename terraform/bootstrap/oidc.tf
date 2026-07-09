###############################################################################
# GitHub Actions OIDC -> IAM role used by the Terraform CI/CD pipeline.
# Created here (one-time, with admin creds) so the pipeline needs no AWS keys.
#
# The role gets AdministratorAccess because it provisions the full platform
# (VPC, EKS, IAM, RDS, ...). Scope it down for least-privilege once the resource
# set is stable. Trust is limited to this GitHub repo.
###############################################################################

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # AWS no longer validates these thumbprints for GitHub's OIDC, but the
  # argument is still required; these are GitHub's well-known values.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = { Purpose = "github-actions-oidc" }
}

data "aws_iam_policy_document" "ci_assume" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "ci" {
  count              = var.enable_github_oidc ? 1 : 0
  name               = "${var.project}-terraform-ci"
  assume_role_policy = data.aws_iam_policy_document.ci_assume[0].json
  tags               = { Purpose = "terraform-ci" }
}

resource "aws_iam_role_policy_attachment" "ci_admin" {
  count      = var.enable_github_oidc ? 1 : 0
  role       = aws_iam_role.ci[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
