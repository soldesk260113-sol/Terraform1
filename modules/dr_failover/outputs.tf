output "health_check_id" {
  description = "The ID of the Route 53 Health Check for the primary environment"
  value       = aws_route53_health_check.onprem_check.id
}

output "sqs_queue_url" {
  value = aws_sqs_queue.failover_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.failover_queue.arn
}
