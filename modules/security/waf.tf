resource "aws_wafv2_web_acl" "main" {
  name        = "${var.environment}-waf"
  description = "${var.environment} 환경을 위한 WAF"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-waf-metric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.environment}-waf"
  }
}
