###############################################################################
# Application Load Balancer - the ONLY internet-facing resource. Lives in the
# public subnets; routes to ECS tasks in the private subnets. All inbound
# internet traffic terminates here (constraint 68).
###############################################################################

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = false # false for engagement teardown

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-alb" })
}

# Target group - payments-api
resource "aws_lb_target_group" "payments" {
  name        = "${var.name_prefix}-tg-payments"
  port        = var.payments_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate uses awsvpc networking -> IP targets

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-tg-payments" })
}

# Target group - kyc-api
resource "aws_lb_target_group" "kyc" {
  name        = "${var.name_prefix}-tg-kyc"
  port        = var.kyc_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-tg-kyc" })
}

# HTTP listener. Default action -> payments; /kyc/* -> kyc.
# In production this listener would be HTTPS (443) with an ACM cert and an
# HTTP->HTTPS redirect; HTTP-only here to avoid a cert dependency in the demo.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payments.arn
  }
}

resource "aws_lb_listener_rule" "kyc" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kyc.arn
  }
  condition {
    path_pattern {
      values = ["/kyc/*", "/verify/*", "/documents/*"]
    }
  }
}
