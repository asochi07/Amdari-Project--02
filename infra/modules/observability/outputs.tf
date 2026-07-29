output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}

output "cloudtrail_arn" {
  value = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.id
}

output "security_hub_account_id" {
  value = aws_securityhub_account.this.id
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.this.name
}

output "honeytoken_secret_arn" {
  value = aws_secretsmanager_secret.honeytoken.arn
}

output "honeytoken_alarm_name" {
  value = aws_cloudwatch_metric_alarm.honeytoken.alarm_name
}

output "containment_lambda_arn" {
  value = aws_lambda_function.containment.arn
}
