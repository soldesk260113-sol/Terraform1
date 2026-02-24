output "cgw_id" {
  value = aws_customer_gateway.this.id
}

output "vgw_id" {
  value = aws_vpn_gateway.this.id
}

output "vpn_connection_id" {
  value = aws_vpn_connection.this.id
}

output "tunnel1_address" {
  value = aws_vpn_connection.this.tunnel1_address
}

output "tunnel1_preshared_key" {
  value     = aws_vpn_connection.this.tunnel1_preshared_key
  sensitive = true
}

