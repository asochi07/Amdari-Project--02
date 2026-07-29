###############################################################################
# CloudTrail (90): multi-region trail, log-file validation, KMS encryption,
# destination S3 bucket with Object Lock (Governance mode) for WORM audit logs.
###############################################################################

# KMS key for CloudTrail log encryption
data "aws_iam_policy_document" "trail_kms" {
  statement {
    sid       = "EnableRoot"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }
  statement {
    sid       = "AllowCloudTrail"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "trail" {
  description             = "${var.name_prefix} CloudTrail log encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.trail_kms.json
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-cloudtrail-kms" })
}

resource "aws_kms_alias" "trail" {
  name          = "alias/${var.name_prefix}-cloudtrail"
  target_key_id = aws_kms_key.trail.key_id
}

# Object-Lock bucket for tamper-proof (WORM) log storage
resource "aws_s3_bucket" "trail" {
  bucket              = "${var.name_prefix}-cloudtrail-${local.account_id}"
  object_lock_enabled = true # must be set at creation
  tags                = merge(local.common_tags, { Name = "${var.name_prefix}-cloudtrail" })
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Object Lock in GOVERNANCE mode - immutable, but overridable by a principal
# holding s3:BypassGovernanceRetention (unlike COMPLIANCE mode).
resource "aws_s3_bucket_object_lock_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    default_retention {
      mode  = "GOVERNANCE"
      years = var.cloudtrail_retention_years
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.trail.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy allowing CloudTrail to write
data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "AclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid       = "Write"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true # tamper-evidence
  kms_key_id                    = aws_kms_key.trail.arn

  depends_on = [aws_s3_bucket_policy.trail]
  tags       = local.common_tags
}

# Access logging for the CloudTrail bucket -> shared detection logs bucket
resource "aws_s3_bucket_logging" "trail" {
  bucket        = aws_s3_bucket.trail.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cloudtrail-access/"
}
