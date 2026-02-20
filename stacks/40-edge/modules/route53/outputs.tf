# 호스팅 존 ID 출력
output "zone_id" {
  value = aws_route53_zone.primary.zone_id
}

# 네임 서버 목록 출력 (가비아 등록용)
output "name_servers" {
  value = aws_route53_zone.primary.name_servers
}

# 생성된 ACM 인증서 ARN 출력 (ALB에서 사용)
output "certificate_arn" {
  value = aws_acm_certificate_validation.cert.certificate_arn
}
