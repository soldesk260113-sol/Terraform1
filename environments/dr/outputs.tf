# 생성된 VPC ID
output "vpc_id" {
  value = module.network.vpc_id
}

# 생성된 ALB DNS 이름
output "alb_dns" {
  value = module.alb.dns_name
}

# ECR 리포지토리 URLs
output "ecr_repository_urls" {
  description = "ECR repository URLs for container images"
  value       = module.ecr.repository_urls
}

# Route53 Name Servers (가비아 설정용)
output "route53_name_servers" {
  description = "Route53 name servers to configure in Gabia"
  value       = module.route53.name_servers
}

# ACM 인증서 ARN
output "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  value       = module.route53.certificate_arn
}
