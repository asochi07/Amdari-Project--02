###############################################################################
# Honeytoken (94) + EventBridge -> Lambda containment (93).
#
# Honeytoken: a decoy IAM user with an access key, whose key is placed in a
# Secrets Manager entry reachable from application memory. The user has NO
# permissions, so the key is useless functionally - but ANY attempt to use it
# is logged by CloudTrail and alarmed, revealing a compromise.
###############################################################################

# --- Honeytoken IAM user (no permissions) + access key ---
resource "aws_iam_user" "honeytoken" {
  name = "${var.name_prefix}-legacy-backup-svc" # innocuous decoy name
  tags = merge(local.common_tags, { Purpose = "honeytoken-do-not-use" })
}

resource "aws_iam_access_key" "honeytoken" {
  user = aws_iam_user.honeytoken.name
}

# Decoy location reachable from app memory: a Secrets Manager entry the app
# environment can read. Attractive to an attacker who dumps app secrets.
resource "aws_secretsmanager_secret" "honeytoken" {
  name                    = var.honeytoken_secret_name
  description             = "Legacy backup service credentials" # plausible decoy
  recovery_window_in_days = 0
  tags                    = merge(local.common_tags, { Purpose = "honeytoken" })
}

resource "aws_secretsmanager_secret_version" "honeytoken" {
  secret_id = aws_secretsmanager_secret.honeytoken.id
  secret_string = jsonencode({
    aws_access_key_id     = aws_iam_access_key.honeytoken.id
    aws_secret_access_key = aws_iam_access_key.honeytoken.secret
  })
}

# CloudWatch metric filter on CloudTrail logs: fires when the honeytoken user
# name appears in any API call (i.e. someone used the decoy key).
resource "aws_cloudwatch_log_group" "trail_events" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = 90
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "honeytoken" {
  name           = "${var.name_prefix}-honeytoken-used"
  log_group_name = aws_cloudwatch_log_group.trail_events.name
  pattern        = "{ $.userIdentity.userName = \"${aws_iam_user.honeytoken.name}\" }"
  metric_transformation {
    name      = "HoneytokenUsed"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "honeytoken" {
  alarm_name          = "${var.name_prefix}-honeytoken-used"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HoneytokenUsed"
  namespace           = "${var.name_prefix}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Honeytoken credential was used - probable compromise"
  treat_missing_data  = "notBreaching"
  tags                = local.common_tags
}

# --- EventBridge -> Lambda containment (93) ---
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "containment" {
  name               = "${var.name_prefix}-containment-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "containment_logs" {
  role       = aws_iam_role.containment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "containment" {
  type        = "zip"
  source_file = "${path.module}/lambda/containment.py"
  output_path = "${path.module}/lambda/containment.zip"
}

resource "aws_lambda_function" "containment" {
  function_name    = "${var.name_prefix}-guardduty-containment"
  runtime          = "python3.12"
  handler          = "containment.handler"
  filename         = data.archive_file.containment.output_path
  source_code_hash = data.archive_file.containment.output_base64sha256
  role             = aws_iam_role.containment.arn
  timeout          = 30
  tags             = local.common_tags
}

# Route high-severity (>= 7.0) GuardDuty findings to the Lambda
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.name_prefix}-guardduty-high-severity"
  description = "Route high-severity GuardDuty findings to containment"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7.0] }]
    }
  })
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "containment" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "containment-lambda"
  arn       = aws_lambda_function.containment.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.containment.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_high.arn
}
