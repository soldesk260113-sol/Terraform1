# Route53 호스팅 존 생성
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# SNS Topic for Operator Alerts (in US-East-1 since Route53 metrics are there)
resource "aws_sns_topic" "dr_notifications" {
  provider = aws.us_east_1
  name     = "dr-operator-notifications"
}

resource "aws_sns_topic_subscription" "operator_email" {
  count    = var.alarm_email != "" ? 1 : 0
  provider = aws.us_east_1
  topic_arn = aws_sns_topic.dr_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# --------------------------------------------------------------------------------
# DNS 레코드 설정 (CloudFront & ALB Failover)
# --------------------------------------------------------------------------------

# 1. WWW 레코드 (Primary: CloudFront)
resource "aws_route53_record" "www_primary" {
  count   = var.use_cloudfront_only ? 0 : 1
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  set_identifier = "www-cloudfront-primary"
  
  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = true # Must be true for failover
  }

  health_check_id = aws_route53_health_check.onprem_internal.id
}

# 1-1. WWW 레코드 (Simple: Always CloudFront)
resource "aws_route53_record" "www_simple" {
  count   = var.use_cloudfront_only ? 1 : 0
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# 2. WWW 레코드 (Secondary: ALB)
resource "aws_route53_record" "www_secondary" {
  count   = var.use_cloudfront_only ? 0 : 1
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  set_identifier = "www-alb-secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.alb_health_check.id
}

# 3. Apex 레코드 (Primary: CloudFront)
resource "aws_route53_record" "apex_primary" {
  count   = var.use_cloudfront_only ? 0 : 1
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "apex-cloudfront-primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.onprem_internal.id
}

# 3-1. Apex 레코드 (Simple: Always CloudFront)
resource "aws_route53_record" "apex_simple" {
  count   = var.use_cloudfront_only ? 1 : 0
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# 4. Apex 레코드 (Secondary: ALB)
resource "aws_route53_record" "apex_secondary" {
  count   = var.use_cloudfront_only ? 0 : 1
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "apex-alb-secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.alb_health_check.id
}

# --------------------------------------------------------------------------------
# Health Check
# --------------------------------------------------------------------------------

# On-premise Monitor for ngrok
resource "aws_route53_health_check" "onprem_internal" {
  fqdn              = var.primary_target_domain
  port              = 443
  type              = "HTTPS_STR_MATCH"
  resource_path     = "/main"
  search_string     = "AI"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "onprem-ngrok-health-check"
  }
}

# ALB Health Check for Route53 Failover
resource "aws_route53_health_check" "alb_health_check" {
  fqdn              = var.alb_dns_name
  port              = 443
  type              = "TCP" # Switch to TCP to ensure "Healthy" if connectivity exists
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "Rosa-cluster-health-check"
  }
}

output "onprem_internal_health_check_id" {
  value = aws_route53_health_check.onprem_internal.id
}

# CloudWatch Alarm in US-East-1 (Required for Route53 Health Checks)
resource "aws_cloudwatch_metric_alarm" "onprem_health_alarm" {
  provider            = aws.us_east_1
  alarm_name          = "onprem-ngrok-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Alarm when on-premise ngrok health check fails"
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.onprem_internal.id
  }
}

# ALB Health Alarm for DR Visibility
resource "aws_cloudwatch_metric_alarm" "alb_health_alarm" {
  provider            = aws.us_east_1
  alarm_name          = "rosa-cluster-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Operator Notification: ROSA Cluster (ALB) health check failed."
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.alb_health_check.id
  }

  alarm_actions = [aws_sns_topic.dr_notifications.arn]
  ok_actions    = [aws_sns_topic.dr_notifications.arn]
}

