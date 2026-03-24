###############################################################
# MODULE: AWS WAF + CLOUDWATCH LOGGING
# Creates:
#   - CloudWatch Log Group (aws-waf-logs)
#   - WAF Web ACL (alb-ip-rate-limit)
#   - Rate-based Rule (100 req/min per IP → Block with HTTP 429)
#   - Custom Response Body
#   - WAF Logging Configuration → CloudWatch
#   - Associate Web ACL with External ALB
###############################################################

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "aws-waf-logs"
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "alb-ip-rate-limit"
  description = "Block more than 100 requests from same IP per minute"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Custom Response Body for 429 rate-limit response
  custom_response_body {
    key          = "rate-limit-429-body"
    content      = "Too many requests. Please try again after 60 Seconds."
    content_type = "TEXT_PLAIN"
  }

  # Rate-based Rule: Block > 100 req/min per IP
  rule {
    name     = "limit_100_req_per_ip"
    priority = 1

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate-limit-429-body"

          response_header {
            name  = "retry-after"
            value = "60"
          }
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "limit100ReqPerIP"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "albIpRateLimit"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "alb-ip-rate-limit"
  }
}

# Associate WAF Web ACL with External ALB
resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = var.ext_lb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# WAF Logging Configuration → CloudWatch
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  depends_on = [aws_wafv2_web_acl_association.alb_association]
}

# CloudWatch Metric Alarm - WAF Blocked Requests
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.project_name}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 60
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Alert when WAF blocks more than 50 requests in 1 minute"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = "us-east-1"
    Rule   = "ALL"
  }

  tags = {
    Name = "${var.project_name}-waf-alarm"
  }
}
