# Route53 호스팅 존 생성
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# --------------------------------------------------------------------------------
# ACM 인증서 발급 및 검증 (자동화)
# --------------------------------------------------------------------------------

# 1. 인증서 요청 (DNS 검증 방식)
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["*.${var.domain_name}"]

  tags = {
    Name = "${var.domain_name}-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. 검증용 DNS 레코드 생성 (Route53에 자동 등록)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

# 3. 검증 완료 대기 (Terraform이 인증서 발급될 때까지 기다림)
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# --------------------------------------------------------------------------------
# DNS 레코드 설정 (Failover)
# --------------------------------------------------------------------------------

# Primary Failover Record (CNAME - Ngrok)
resource "aws_route53_record" "www_primary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"

  failover_routing_policy {
    type = "PRIMARY"
  }
  set_identifier  = "primary"
  ttl             = 60
  records         = [var.primary_target_domain]
  health_check_id = var.primary_health_check_id
}

# Secondary Failover Record (CNAME - ALB)
resource "aws_route53_record" "www_secondary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"

  failover_routing_policy {
    type = "SECONDARY"
  }
  set_identifier = "dr"
  ttl            = 60
  records        = [var.alb_dns_name]
}
