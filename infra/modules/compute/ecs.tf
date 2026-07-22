###############################################################################
# ECS Fargate - cluster, task definitions, and two services (payments, kyc)
# running in the PRIVATE subnets (constraint 71: no compute internet-
# addressable; 74: private subnets across >= 2 AZs). Each service uses its own
# task role from the identity module (constraint 73: separate identities).
###############################################################################

# Execution role (image pull + logs). Created here if one isn't supplied.
data "aws_iam_policy_document" "exec_assume" {
  count = var.execution_role_arn == "" ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  count              = var.execution_role_arn == "" ? 1 : 0
  name               = "${var.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.exec_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  count      = var.execution_role_arn == "" ? 1 : 0
  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

locals {
  execution_role_arn = var.execution_role_arn != "" ? var.execution_role_arn : aws_iam_role.execution[0].arn
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-cluster" })
}

# CloudWatch log groups per service
resource "aws_cloudwatch_log_group" "payments" {
  name              = "/ecs/${var.name_prefix}/payments-api"
  retention_in_days = 30
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "kyc" {
  name              = "/ecs/${var.name_prefix}/kyc-api"
  retention_in_days = 30
  tags              = local.common_tags
}

# ---- payments-api task definition + service ----
resource "aws_ecs_task_definition" "payments" {
  family                   = "${var.name_prefix}-payments"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = var.payments_task_role_arn

  container_definitions = jsonencode([{
    name         = "payments-api"
    image        = var.container_image
    essential    = true
    portMappings = [{ containerPort = var.payments_container_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.payments.name
        "awslogs-region"        = "af-south-1"
        "awslogs-stream-prefix" = "payments"
      }
    }
  }])
  tags = merge(local.common_tags, { Service = "payments-api" })
}

resource "aws_ecs_service" "payments" {
  name            = "${var.name_prefix}-payments"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.payments.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids # private only
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false # not internet-addressable
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.payments.arn
    container_name   = "payments-api"
    container_port   = var.payments_container_port
  }

  depends_on = [aws_lb_listener.http]
  tags       = merge(local.common_tags, { Service = "payments-api" })
}

# ---- kyc-api task definition + service ----
resource "aws_ecs_task_definition" "kyc" {
  family                   = "${var.name_prefix}-kyc"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = var.kyc_task_role_arn

  container_definitions = jsonencode([{
    name         = "kyc-api"
    image        = var.container_image
    essential    = true
    portMappings = [{ containerPort = var.kyc_container_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.kyc.name
        "awslogs-region"        = "af-south-1"
        "awslogs-stream-prefix" = "kyc"
      }
    }
  }])
  tags = merge(local.common_tags, { Service = "kyc-api" })
}

resource "aws_ecs_service" "kyc" {
  name            = "${var.name_prefix}-kyc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.kyc.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kyc.arn
    container_name   = "kyc-api"
    container_port   = var.kyc_container_port
  }

  depends_on = [aws_lb_listener.http]
  tags       = merge(local.common_tags, { Service = "kyc-api" })
}
