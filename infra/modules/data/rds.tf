###############################################################################
# RDS PostgreSQL. Private subnets only, no public access, customer-managed KMS
# encryption at rest, SG ingress by reference. Master password sourced from the
# generated random_password (stored in Secrets Manager), never hardcoded.
###############################################################################

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.common_tags, { Name = "${var.name_prefix}-db-subnets" })
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result # from Secrets Manager-backed generator

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # private only

  # Encryption at rest with the customer-managed key
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Enforce TLS and sensible operational defaults
  multi_az                     = false # single-AZ for cost in this engagement; document HA option
  backup_retention_period      = 7
  deletion_protection          = false # false so the engagement can destroy; true in production
  skip_final_snapshot          = true  # engagement teardown; take a final snapshot in production
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false
  copy_tags_to_snapshot        = true

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-postgres" })
}
