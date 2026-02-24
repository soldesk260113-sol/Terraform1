

output "sqs_queue_url" {
  value = aws_sqs_queue.failover_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.failover_queue.arn
}

output "failover_queue_url" {
  description = "The URL of the SQS queue for failover messages"
  value       = aws_sqs_queue.failover_queue.id
}
