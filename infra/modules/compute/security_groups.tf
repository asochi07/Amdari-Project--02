###############################################################################
# Security groups for the edge->compute path.
#   ALB SG:  accepts 80/443 from the internet (it is the only public entry).
#   Task SG: accepts traffic ONLY from the ALB SG, by reference. This SG id is
#            exported so the data module can admit it to RDS/ElastiCache by
#            reference (closing the Day 7 deferred wiring).
###############################################################################

locals {
  common_tags = merge(var.tags, { Project = var.name_prefix, ManagedBy = "terraform" })
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB - public ingress on 80/443"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_security_group_rule" "alb_http_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from internet (redirected to HTTPS in production)"
}

resource "aws_security_group_rule" "alb_https_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from internet"
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound to targets"
}

# Task SG - ingress ONLY from the ALB SG, by reference (not CIDR).
resource "aws_security_group" "task" {
  name        = "${var.name_prefix}-task-sg"
  description = "ECS tasks - ingress only from the ALB security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name_prefix}-task-sg" })
}

resource "aws_security_group_rule" "task_from_alb_payments" {
  type                     = "ingress"
  from_port                = var.payments_container_port
  to_port                  = var.payments_container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.task.id
  source_security_group_id = aws_security_group.alb.id
  description              = "Payments container port from ALB (by reference)"
}

resource "aws_security_group_rule" "task_from_alb_kyc" {
  count                    = var.kyc_container_port != var.payments_container_port ? 1 : 0
  type                     = "ingress"
  from_port                = var.kyc_container_port
  to_port                  = var.kyc_container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.task.id
  source_security_group_id = aws_security_group.alb.id
  description              = "KYC container port from ALB (by reference)"
}

resource "aws_security_group_rule" "task_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.task.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound (image pull via NAT, AWS APIs, RDS/cache)"
}
