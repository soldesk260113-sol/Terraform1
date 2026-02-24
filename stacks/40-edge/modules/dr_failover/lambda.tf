# --------------------------------------------------------------------------------
# Automated Failover Lambda (replaces dr-worker pod)
# --------------------------------------------------------------------------------

# 1. IAM Role for Lambda
resource "aws_iam_role" "lambda_failover_role" {
  name = "${var.environment}-dr-failover-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# 2. IAM Policy for Lambda (SQS, RDS, Logs, Network)
resource "aws_iam_policy" "lambda_failover_policy" {
  name        = "${var.environment}-dr-failover-lambda-policy"
  description = "Policy allowing Lambda to read SQS, manage RDS, and write logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.failover_queue.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:PromoteReadReplica",
          "rds:DescribeDBInstances"
        ]
        Resource = "*" # TODO: restrict to specific RDS ARNs if needed
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dms:StartReplicationTask",
          "dms:StopReplicationTask",
          "dms:DescribeReplicationTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_policy" {
  role       = aws_iam_role.lambda_failover_role.name
  policy_arn = aws_iam_policy.lambda_failover_policy.arn
}


# 3. Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.environment}-dr-lambda-sg"
  description = "Security group for DR Failover Lambda"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Lambda Function
resource "aws_lambda_function" "dr_failover_lambda" {
  filename      = "${path.module}/failover_python.zip"
  function_name = "${var.environment}-failover-orchestrator" # 이름을 좀 더 명확하게 변경
  role          = aws_iam_role.lambda_failover_role.arn
  handler       = "unified_failover.lambda_handler" # 핸들러 이름 맞춰줌
  runtime       = "python3.11"
  timeout       = 300 # 30s -> 300s (DMS 작업 및 RDS 승격 시간 확보)
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      RDS_INSTANCE_ID     = var.rds_cluster_identifier
      OPENSHIFT_API_URL   = var.openshift_api_url
      OPENSHIFT_TOKEN     = var.openshift_token
      OPENSHIFT_NAMESPACE = "production"
      
      # DMS Tasks
      FORWARD_TASK_ARN    = var.forward_task_arn
      REVERSE_TASK_ARN    = var.reverse_task_arn
      ON_PREM_HOST        = var.onprem_host

      # Alarms & Signals
      PRIMARY_ALARM_NAME    = var.alarm_name
    }
  }

  # Ensure the log group exists
  depends_on = [aws_iam_role_policy_attachment.lambda_attach_policy, data.archive_file.lambda_zip]
}

# 5. SQS Trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.failover_queue.arn
  function_name    = aws_lambda_function.dr_failover_lambda.arn
  batch_size       = 1 # Process one failure event at a time
}

# 6. EventBridge Rule for DMS Failback Monitoring (추가)
resource "aws_cloudwatch_event_rule" "recovery_monitor" {
  name                = "${var.environment}-recovery-monitor-rule"
  description         = "DMS 역방향 지연 시간 및 복구 상태 주기적 체크"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda_monitor" {
  rule      = aws_cloudwatch_event_rule.recovery_monitor.name
  target_id = "UnifiedFailoverLambda"
  arn       = aws_lambda_function.dr_failover_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dr_failover_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.recovery_monitor.arn
}

# 7. Package Python Code for Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/failover_python.zip"
  source_file = "${path.module}/unified_failover.py" # 소스 파일 변경
}
