terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --------------------------------------------------------------------------------
# 1. Safety & Control (EventBridge Rule acting as a switch)
# --------------------------------------------------------------------------------

# Rule in US-East-1 (Source of Alarm Change)
resource "aws_cloudwatch_event_rule" "failover_trigger_us_east_1" {
  provider    = aws.us_east_1
  name        = "dr-failover-trigger-rule"
  description = "Route53 장애 알람을 리전 간 전달 (Source Region)"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state     = { value = ["ALARM"] }
      alarmName = [var.alarm_name]
    }
  })
}

# IAM Role for EventBridge to PutEvents to Target Region
resource "aws_iam_role" "eventbridge_cross_region" {
  provider = aws.us_east_1
  name     = "dr-eventbridge-cross-region-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "events.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge_cross_region_policy" {
  provider = aws.us_east_1
  name     = "dr-eventbridge-cross-region-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_cross_region_attach" {
  provider   = aws.us_east_1
  role       = aws_iam_role.eventbridge_cross_region.name
  policy_arn = aws_iam_policy.eventbridge_cross_region_policy.arn
}

# Target: Application Region Event Bus
resource "aws_cloudwatch_event_target" "target_region_bus" {
  provider  = aws.us_east_1
  rule      = aws_cloudwatch_event_rule.failover_trigger_us_east_1.name
  target_id = "TargetRegionEventBus"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn  = aws_iam_role.eventbridge_cross_region.arn
}

# --------------------------------------------------------------------------------
# 2. Detection & Alert (Route53, CloudWatch, SQS)
# --------------------------------------------------------------------------------

# 2-1. SQS Queue in Application Region
resource "aws_sqs_queue" "failover_queue" {
  name                      = var.dr_failover_queue_name
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days
}

# Queue Policy to allow EventBridge
resource "aws_sqs_queue_policy" "failover_queue_policy" {
  queue_url = aws_sqs_queue.failover_queue.id
  policy    = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.failover_queue.arn
      }
    ]
  })
}

# EventBridge Rule in Application Region (Receiver)
resource "aws_cloudwatch_event_rule" "failover_trigger_local" {
  name        = "dr-failover-trigger-rule-local"
  description = "Route53 장애 알람 수신 및 SQS 전달 (Destination Region)"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state     = { value = ["ALARM"] }
      alarmName = [var.alarm_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "sqs_target" {
  rule      = aws_cloudwatch_event_rule.failover_trigger_local.name
  target_id = "FailoverQueue"
  arn       = aws_sqs_queue.failover_queue.arn
}


# 2-2. Route 53 Health Check (Global)
# [주의] Route53 Health Check 메트릭은 항상 us-east-1 (버지니아) 리전에 생성됩니다.
# 따라서 CloudWatch Alarm 및 EventBridge Trigger 설정 시 aws.us_east_1 provider가 필수입니다.
# [중요] 도메인으로 체크하여 전체 경로(FW → WAF → Ingress VIP → K8S) 모니터링
resource "aws_route53_health_check" "onprem_check" {
  fqdn              = var.primary_target_domain
  type              = var.health_check_type
  port              = var.health_check_port
  resource_path     = "/health/global-status"
  failure_threshold = 3
  request_interval  = 30
  provider          = aws.us_east_1
}

# 2-3. SNS Topic & Subscription (US-East-1)
resource "aws_sns_topic" "onprem_failure" {
  provider = aws.us_east_1
  name     = "On-Prem-Disaster-Topic"
}

resource "aws_sns_topic_subscription" "email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.onprem_failure.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# 2-4. CloudWatch Alarm (US-East-1)
resource "aws_cloudwatch_metric_alarm" "onprem_failure_alarm" {
  provider            = aws.us_east_1
  alarm_name          = var.alarm_name
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "온프레미스 VM(ngrok)의 상태 검사가 실패하여 발생한 장애 알람입니다. 이 알람이 발생하면 Route 53이 트래픽을 AWS DR 환경으로 Failover하며, EventBridge를 통해 SQS로 장애 메시지가 전송됩니다."
  alarm_actions       = [aws_sns_topic.onprem_failure.arn]
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.onprem_check.id
  }
}

# --------------------------------------------------------------------------------
# 3. Execution & Recovery (VPC Endpoints, IAM, K8s)
# --------------------------------------------------------------------------------

# 3-1. VPC Interface Endpoints
# Security Group allowing HTTPS from VPC CIDR should be passed in var.security_group_ids

resource "aws_vpc_endpoint" "sqs" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.sqs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnet_ids
  security_group_ids = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "rds" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.rds"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnet_ids
  security_group_ids = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnet_ids
  security_group_ids = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnet_ids
  security_group_ids = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnet_ids
  security_group_ids = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "monitoring" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnet_ids
  security_group_ids = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
}

# 3-2. IAM Role for Service Account (IRSA)
resource "aws_iam_policy" "worker_policy" {
  name        = "dr-failover-worker-policy"
  description = "Policy for DR Failover Worker"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes",
          "rds:PromoteReadReplica", "rds:DescribeDBInstances",
          "ec2:DescribeVpnConnections", "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "worker_role" {
  name = "dr-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.cluster_oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.cluster_service_account_namespace}:${var.cluster_service_account_name}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.worker_policy.arn
}
