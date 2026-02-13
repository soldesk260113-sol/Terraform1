output "web_sg_id" { # Web 보안 그룹 ID
  value = aws_security_group.web_sg.id
}

output "waf_arn" { # WAF ARN
  value = aws_wafv2_web_acl.main.arn
}
