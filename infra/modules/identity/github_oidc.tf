###############################################################################
# GitHub Actions OIDC federation (constraint 85). GitHub Actions exchanges a
# short-lived OIDC token for an AWS session - no long-lived pipeline keys.
# The deploy role's trust policy is scoped to this specific repo.
###############################################################################

# GitHub's OIDC provider. Thumbprint list is required by the API; GitHub's
# certificate chain is validated by AWS regardless of the value supplied.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = local.common_tags
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Scope trust to this repository only (any branch). Tighten to a ref for prod.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.name_prefix}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_assume.json
  max_session_duration = 3600
  tags                 = merge(local.common_tags, { Purpose = "github-oidc-deploy" })
}

# Deploy permissions are intentionally minimal here; expand per pipeline needs
# in Week 3. Kept scoped rather than AdministratorAccess (no wildcard grant).
data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "DescribeForPlan"
    effect    = "Allow"
    actions   = ["ecs:Describe*", "ecs:List*", "ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = ["*"] # these describe/list actions do not support resource scoping
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.name_prefix}-github-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
