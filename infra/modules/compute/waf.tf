###############################################################################
# AWS WAF - attached to the ALB (constraint 69). Managed rule groups for the
# AWS Common set, SQLi, and XSS-relevant protections, plus a CUSTOM rate-limit
# rule scoped to the payments endpoint path.
###############################################################################

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name_prefix}-web-acl"
  description = "WAF for SentinelPay ALB - managed rules + payments rate limit"
  scope       = "REGIONAL" # ALB is regional (CLOUDFRONT scope is for CloudFront)

  default_action {
    allow {}
  }

  # 1) AWS Common rule set
  rule {
    name     = "AWSCommonRules"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  # 2) SQL injection rule set
  rule {
    name     = "AWSSQLiRules"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # 3) Known-bad-inputs set (covers XSS and other common exploit patterns)
  rule {
    name     = "AWSKnownBadInputs"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-badinputs"
      sampled_requests_enabled   = true
    }
  }

  # 4) CUSTOM rate-limit rule scoped to the payments endpoint (constraint 69)
  rule {
    name     = "PaymentsRateLimit"
    priority = 10
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
        scope_down_statement {
          byte_match_statement {
            positional_constraint = "STARTS_WITH"
            search_string         = "/payments"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-payments-ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-web-acl" })
}

# Attach the web ACL to the ALB
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
