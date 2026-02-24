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
  value = aws_acm_certificate_validation.cert_ap_northeast_2.certificate_arn
}

# 장애 조치 트리거용 알람 이름
output "failover_alarm_name" {
  value = aws_cloudwatch_metric_alarm.onprem_health_alarm.alarm_name
}

output "secondary_failover_alarm_name" {
  value = aws_cloudwatch_metric_alarm.alb_health_alarm.alarm_name
}
