output "dns_name" { # ALB DNS 이름
  value = aws_lb.main.dns_name
}

output "zone_id" { # ALB Zone ID (Route53 Alias용)
  value = aws_lb.main.zone_id
}
