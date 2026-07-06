###############################################################################
# KMS - customer-managed keys with policy separation between key ADMINISTRATORS
# and key USERS (case study constraint: admin/use principals must be separate).
# One key per data domain so blast radius and rotation are independent.
###############################################################################

data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.tags, { Project = var.name_prefix, ManagedBy = "terraform" })
  account_id  = data.aws_caller_identity.current.account_id
  root_arn    = "arn:aws:iam::${local.account_id}:root"
  # Admins: explicit admin ARNs if supplied, else fall back to account root.
  admin_arns = length(var.kms_admin_arns) > 0 ? var.kms_admin_arns : [local.root_arn]
}

# Reusable key policy: administrators manage the key; the account root can grant
# use via IAM policies (service principals use the key through grants/IAM).
data "aws_iam_policy_document" "kms" {
  # Administration - scoped to the admin principals only
  statement {
    sid    = "KeyAdministration"
    effect = "Allow"
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
      "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
      "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = local.admin_arns
    }
  }
  # Use - encryption/decryption, granted to IAM principals in the account.
  # Separation: this statement grants USE, never key-policy administration.
  statement {
    sid       = "KeyUsage"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
  }
  # Allow AWS services (RDS, S3, etc.) to use the key on behalf of the account.
  statement {
    sid       = "AllowServiceUse"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com", "elasticache.amazonaws.com", "s3.amazonaws.com", "secretsmanager.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "rds" {
  description             = "${var.name_prefix} RDS encryption key (customer-managed)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-rds-kms" })
}
resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "cache" {
  description             = "${var.name_prefix} ElastiCache encryption key (customer-managed)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-cache-kms" })
}
resource "aws_kms_alias" "cache" {
  name          = "alias/${var.name_prefix}-cache"
  target_key_id = aws_kms_key.cache.key_id
}

resource "aws_kms_key" "s3" {
  description             = "${var.name_prefix} S3 encryption key (customer-managed)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-s3-kms" })
}
resource "aws_kms_alias" "s3" {
  name          = "alias/${var.name_prefix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_kms_key" "secrets" {
  description             = "${var.name_prefix} Secrets Manager encryption key (customer-managed)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-secrets-kms" })
}
resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}
