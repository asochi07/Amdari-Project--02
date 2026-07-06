###############################################################################
# Security groups. Ingress to the data stores is restricted to the application
# security groups BY REFERENCE (source_security_group_id), never by CIDR, per
# the data-plane constraint. If no app SGs are supplied yet (data plane built
# before compute), the SGs are created with no ingress - closed by default.
###############################################################################

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS Postgres - ingress from application security groups only"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name_prefix}-rds-sg" })
}

resource "aws_security_group" "cache" {
  name        = "${var.name_prefix}-cache-sg"
  description = "ElastiCache - ingress from application security groups only"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name_prefix}-cache-sg" })
}

# Postgres ingress (5432) from each app SG, by reference.
resource "aws_security_group_rule" "rds_from_app" {
  count                    = length(var.app_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.app_security_group_ids[count.index]
  description              = "Postgres from application SG (by reference)"
}

# Redis ingress (6379) from each app SG, by reference.
resource "aws_security_group_rule" "cache_from_app" {
  count                    = length(var.app_security_group_ids)
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cache.id
  source_security_group_id = var.app_security_group_ids[count.index]
  description              = "Redis from application SG (by reference)"
}

# Egress: allow outbound (needed for the engines to function); no inbound from world.
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound"
}
resource "aws_security_group_rule" "cache_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cache.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound"
}
