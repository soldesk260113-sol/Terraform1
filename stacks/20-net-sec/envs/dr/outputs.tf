output "web_acl_arn" {
  value       = module.waf_webacl.web_acl_arn
  description = "The ARN of the WAF WebACL"
}

output "vpn_test_sg_id" {
  value = module.vpn_test_sg.sg_id
}
