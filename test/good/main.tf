terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region                      = "af-south-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

resource "aws_kms_key" "k" {
  description         = "cmk"
  enable_key_rotation = true
}

resource "aws_s3_bucket" "good" {
  bucket = "sentinelpay-good-bucket-example"
}
resource "aws_s3_bucket_public_access_block" "good" {
  bucket                  = aws_s3_bucket.good.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "good" {
  bucket = aws_s3_bucket.good.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.k.arn
    }
  }
}

resource "aws_security_group" "good" {
  name   = "good-sg"
  vpc_id = "vpc-123"
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-appref"]
  }
}

resource "aws_iam_role" "good" {
  name               = "good-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "good" {
  name   = "good-policy"
  role   = aws_iam_role.good.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = ["arn:aws:secretsmanager:af-south-1:123456789012:secret:sentinelpay/*"] }] })
}

resource "aws_db_instance" "good" {
  identifier          = "good-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "admin"
  password            = "changeme12345"
  storage_encrypted   = true
  kms_key_id          = aws_kms_key.k.arn
  skip_final_snapshot = true
}

resource "aws_vpc" "good" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_cloudwatch_log_group" "flow" {
  name = "/vpc/flow"
}
resource "aws_iam_role" "flowrole" {
  name               = "flow-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_flow_log" "good" {
  vpc_id          = aws_vpc.good.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flowrole.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
}
