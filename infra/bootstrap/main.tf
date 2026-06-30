###############################################################################
# Bootstrap: creates the Terraform remote-state backend resources.
#
# Chicken-and-egg: the S3 bucket and DynamoDB lock table that the MAIN config
# uses as its backend must exist first. This small config uses LOCAL state to
# create them once. Run `terraform init && terraform apply` here a single time;
# thereafter the main config points its S3 backend at these resources.
###############################################################################

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # NOTE: bootstrap intentionally uses LOCAL state (no backend block) — it has
  # to, because it is creating the remote backend itself.
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region for the state backend"
  type        = string
  default     = "af-south-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state"
  type        = string
  default     = "sentinelpay-tfstate-asochi07"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "sentinelpay-tflock"
}

# --- S3 bucket: stores the Terraform state file ---
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
}

# Versioning: keep history of state files so a bad apply can be recovered.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption: state can contain secrets, so it must be encrypted at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block all public access to the state bucket — it must never be public.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table: provides state locking ---
# A LockID hash key is the convention Terraform's S3 backend expects.
resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "lock_table" {
  value = aws_dynamodb_table.lock.id
}

# --- Access logging: a separate bucket to receive state-bucket access logs ---
resource "aws_s3_bucket" "logs" {
  bucket = "${var.state_bucket_name}-logs"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Send access logs from the state bucket into the logs bucket.
resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "state-access/"
}

# --- Enforce HTTPS-only (deny any request not using TLS) on the state bucket ---
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}
