output "web_acl_arn" {
  value       = module.waf_webacl.web_acl_arn
  description = "The ARN of the WAF WebACL"
}

output "web_acl_id" {
  value       = module.waf_webacl.web_acl_id
  description = "The ID of the WAF WebACL"
}

output "web_acl_name" {
  value       = module.waf_webacl.web_acl_name
  description = "The Name of the WAF WebACL"
}

output "vpn_sg_id" {
  value       = module.vpn_sg.sg_id
  description = "The ID of the VPN Security Group"
}

output "vpn_connection_id" {
  value       = module.s2s_vpn.vpn_connection_id
  description = "The ID of the VPN Connection"
}

output "vgw_id" {
  value       = module.s2s_vpn.vgw_id
  description = "The ID of the VPN Gateway"
}

output "cgw_id" {
  value       = module.s2s_vpn.cgw_id
  description = "The ID of the Customer Gateway"
}

# --- VPN Connection details for On-Prem Setup ---

output "onprem_public_ip" {
  value       = var.onprem_public_ip
  description = "Public IP of On-Premise device"
}

output "onprem_cidrs" {
  value       = var.onprem_cidrs
  description = "On-Premise Network CIDR blocks"
}

output "aws_vpc_cidr" {
  value       = data.terraform_remote_state.base.outputs.vpc_cidr
  description = "AWS VPC Network CIDR"
}

output "vpn_tunnel1_address" {
  value       = module.s2s_vpn.tunnel1_address
  description = "AWS Side VPN Public IP (Tunnel 1)"
}

output "vpn_tunnel1_preshared_key" {
  value       = module.s2s_vpn.tunnel1_preshared_key
  description = "VPN Pre-Shared Key for Tunnel 1"
  sensitive   = true
}
