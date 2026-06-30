###############################################################################
# Network module: VPC with public + private subnets across two AZs,
# internet gateway, per-AZ NAT gateways, route tables, and VPC flow logs.
#
# Constraints satisfied (case study Section 8):
#  - Private subnets across >= 2 AZs for app compute and RDS
#  - No application compute directly internet-addressable (private subnets
#    have no route to the IGW; egress is via NAT only)
#  - VPC Flow Logs enabled (closes V-CLD-08)
###############################################################################

locals {
  common_tags = merge(var.tags, { Project = var.name_prefix, ManagedBy = "terraform" })
}

# --- VPC ---
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.name_prefix}-vpc" })
}

# --- Internet Gateway (gives PUBLIC subnets a route out) ---
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-igw" })
}

# --- Public subnets (one per AZ): ALB and NAT live here, NOT app compute ---
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # we do not auto-assign public IPs; ALB/NAT manage their own
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

# --- Private subnets (one per AZ): app compute + RDS live here ---
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-private-${var.azs[count.index]}"
    Tier = "private"
  })
}

# --- Elastic IPs for the NAT gateways (one per AZ) ---
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-nat-eip-${var.azs[count.index]}" })
}

# --- NAT gateways (one per AZ, in the PUBLIC subnets): outbound egress for
#     private subnets without making them inbound-reachable ---
resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.common_tags, { Name = "${var.name_prefix}-nat-${var.azs[count.index]}" })
  depends_on    = [aws_internet_gateway.this]
}

# --- Public route table: 0.0.0.0/0 -> IGW ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private route tables (one per AZ): 0.0.0.0/0 -> that AZ's NAT ---
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-rt-private-${var.azs[count.index]}" })
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- VPC Flow Logs (closes V-CLD-08) ---
# Log group destination
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  tags              = local.common_tags
}

# IAM role allowing the VPC Flow Logs service to write to CloudWatch
data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "${var.name_prefix}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "flow_permissions" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "${var.name_prefix}-vpc-flow-logs"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_permissions.json
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  tags            = merge(local.common_tags, { Name = "${var.name_prefix}-flow-logs" })
}
