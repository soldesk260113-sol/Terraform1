output "bucket_id" {
  description = "DR backup S3 bucket ID"
  value       = aws_s3_bucket.dr_backup.id
}

output "bucket_arn" {
  description = "DR backup S3 bucket ARN"
  value       = aws_s3_bucket.dr_backup.arn
}
