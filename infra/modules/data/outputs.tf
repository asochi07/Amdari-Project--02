output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.this.address
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "cache_primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "cache_security_group_id" {
  value = aws_security_group.cache.id
}

output "app_bucket" {
  value = aws_s3_bucket.app.id
}

output "db_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = aws_secretsmanager_secret.db.arn
}

output "cache_auth_secret_arn" {
  value = aws_secretsmanager_secret.cache_auth.arn
}

output "kms_key_arns" {
  description = "Customer-managed KMS key ARNs by domain"
  value = {
    rds     = aws_kms_key.rds.arn
    cache   = aws_kms_key.cache.arn
    s3      = aws_kms_key.s3.arn
    secrets = aws_kms_key.secrets.arn
  }
}
