output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs"
  value       = module.ecr.repository_arns
}

output "s3_bucket_id" {
  description = "DR backup S3 bucket ID"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "DR backup S3 bucket ARN"
  value       = module.s3.bucket_arn
}
