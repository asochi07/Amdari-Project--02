###############################################################################
# ECS task roles - SEPARATE identity per service (constraint 73), each scoped
# to ONLY the resources that service consumes. No IAM wildcards on resources.
###############################################################################

locals {
  common_tags = merge(var.tags, { Project = var.name_prefix, ManagedBy = "terraform" })
}

# Trust policy: ECS tasks assume these roles.
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------- payments-api task role ----------
resource "aws_iam_role" "payments_task" {
  name               = "${var.name_prefix}-payments-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = merge(local.common_tags, { Service = "payments-api" })
}

data "aws_iam_policy_document" "payments_perms" {
  # Read only the payments secrets it needs
  dynamic "statement" {
    for_each = length(var.payments_secret_arns) > 0 ? [1] : []
    content {
      sid       = "ReadPaymentsSecrets"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = var.payments_secret_arns
    }
  }
  # Use only the KMS keys backing those secrets/data
  dynamic "statement" {
    for_each = length(var.payments_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "UsePaymentsKeys"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
      resources = var.payments_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "payments_task" {
  # Only attach if there is at least one statement to grant
  count  = (length(var.payments_secret_arns) + length(var.payments_kms_key_arns)) > 0 ? 1 : 0
  name   = "${var.name_prefix}-payments-task"
  role   = aws_iam_role.payments_task.id
  policy = data.aws_iam_policy_document.payments_perms.json
}

# ---------- kyc-api task role ----------
resource "aws_iam_role" "kyc_task" {
  name               = "${var.name_prefix}-kyc-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = merge(local.common_tags, { Service = "kyc-api" })
}

data "aws_iam_policy_document" "kyc_perms" {
  dynamic "statement" {
    for_each = length(var.kyc_secret_arns) > 0 ? [1] : []
    content {
      sid       = "ReadKycSecrets"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = var.kyc_secret_arns
    }
  }
  dynamic "statement" {
    for_each = length(var.kyc_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "UseKycKeys"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
      resources = var.kyc_kms_key_arns
    }
  }
  # kyc-api reads/writes KYC documents in the app bucket, scoped to that bucket
  dynamic "statement" {
    for_each = var.app_bucket_arn != "" ? [1] : []
    content {
      sid       = "KycBucketAccess"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${var.app_bucket_arn}/*"]
    }
  }
}

resource "aws_iam_role_policy" "kyc_task" {
  count  = (length(var.kyc_secret_arns) + length(var.kyc_kms_key_arns) + (var.app_bucket_arn != "" ? 1 : 0)) > 0 ? 1 : 0
  name   = "${var.name_prefix}-kyc-task"
  role   = aws_iam_role.kyc_task.id
  policy = data.aws_iam_policy_document.kyc_perms.json
}
