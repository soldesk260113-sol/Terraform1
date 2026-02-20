resource "aws_security_group" "this" {
  name        = var.name
  description = "VPN validation security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allow_icmp ? [1] : []
    content {
      description = "ICMP from On-Prem"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = [var.onprem_cidr]
    }
  }

  dynamic "ingress" {
    for_each = var.allow_ssh ? [1] : []
    content {
      description = "SSH from On-Prem"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.onprem_cidr]
    }
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.name
  }
}

