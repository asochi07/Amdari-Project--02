###############################################################################
# ElastiCache (Redis). Private subnets, encryption in transit AND at rest with
# the customer-managed key, AUTH token from Secrets Manager-backed generator.
###############################################################################

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-cache-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.common_tags, { Name = "${var.name_prefix}-cache-subnets" })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "${var.name_prefix} Redis - encrypted in transit and at rest"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.cache_node_type
  num_cache_clusters   = 1
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.cache.id]

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.cache.arn
  auth_token                 = random_password.cache_auth.result

  automatic_failover_enabled = false # single node for cost; document multi-node HA
  tags                       = merge(local.common_tags, { Name = "${var.name_prefix}-redis" })
}
