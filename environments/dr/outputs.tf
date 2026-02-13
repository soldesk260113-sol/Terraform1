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

output "vpn_tunnel1_public_ip" {
  description = "Libreswan 설정 파일(aws.conf)의 'right' 값"
  value       = module.network.vpn_tunnel1_address
}

output "vpn_tunnel2_public_ip" {
  description = "HA 구성용 Tunnel 2 Public IP"
  value       = module.network.vpn_tunnel2_address
}

output "ec2_instance_id" {
  description = "SSM으로 접속할 인스턴스 ID"
  value       = aws_instance.vpn_tester.id
}
