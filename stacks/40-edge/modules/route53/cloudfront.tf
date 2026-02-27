resource "aws_acm_certificate" "cert_us_east_1" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_route53_record" "cert_validation_us_east_1" {
  for_each = {
    for dvo in aws_acm_certificate.cert_us_east_1.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "cert_us_east_1" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert_us_east_1.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_us_east_1 : record.fqdn]
}

# ACM Certificate for ALB (ap-northeast-2)
resource "aws_acm_certificate" "cert_ap_northeast_2" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_route53_record" "cert_validation_ap_northeast_2" {
  for_each = {
    for dvo in aws_acm_certificate.cert_ap_northeast_2.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "cert_ap_northeast_2" {
  certificate_arn         = aws_acm_certificate.cert_ap_northeast_2.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_ap_northeast_2 : record.fqdn]
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for ${var.domain_name}"

  aliases = ["www.${var.domain_name}", var.domain_name]
  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  # 1. On-premise Origin (ngrok)
  origin {
    domain_name = var.primary_target_domain
    origin_id   = "onprem-ngrok"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Forwarded-Host"
      value = "www.${var.domain_name}"
    }
  }

  # 2. AWS DR Origin (ALB)
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "aws-dr-alb"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }
  }

  # 3. Origin Group for Failover
  origin_group {
    origin_id = "failover-group"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "onprem-ngrok"
    }

    member {
      origin_id = "aws-dr-alb"
    }
  }

  # This is the CRITICAL part for ERR_NGROK_3200
  # CloudFront by default sends the Alias as Host header. 
  # ngrok free requires the ngrok domain in Host header.
  # We use a Origin Request Policy to NOT forward the Host header, 
  # so CloudFront uses the 'domain_name' from the origin as the Host header.

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "failover-group"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirects.arn
    }
  }

  # Ordered Cache Behavior for AI API (Direct to ALB to allow POST)
  ordered_cache_behavior {
    path_pattern     = "/api/ai*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "aws-dr-alb" # Origin Group 대신 직접 ALB로 보냄 (POST 허용을 위해)

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method", "Host"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_us_east_1.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Environment = var.environment
  }

  # monitoring_subscription {
  #   monitoring_status = "Enabled"
  # }
}

# CloudFront Function for Redirects
resource "aws_cloudfront_function" "redirects" {
  name    = "redirects"
  runtime = "cloudfront-js-1.0"
  comment = "Apex to WWW and Root to /main redirects"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;
    var uri = request.uri;

    // 1. Apex to WWW Redirect
    if (host === "${var.domain_name}") {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                "location": { "value": "https://www." + host + uri }
            }
        };
    }

    // 2. Root to /main Redirect
    if (uri === "/") {
        return {
            statusCode: 302,
            statusDescription: 'Found',
            headers: {
                "location": { "value": "/main" }
            }
        };
    }

    return request;
}
EOF
}
