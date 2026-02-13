variable "environment" {
  description = "환경 이름 (예: prod, dr)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}

variable "azs" {
  description = "List of Availability Zones"
  type        = list(string)
}

variable "on_prem_cidr" {
  description = "CIDR block for On-Premise network"
  type        = string
  default     = "10.2.2.0/24" # [확인됨] 현재 온프레미스 네트워크 대역 (10.2.2.40/24)
}

variable "customer_gateway_ip" {
  description = "Public IP address of the on-premises VPN device"
  type        = string
  default     = "121.160.41.205" # [확인됨] 현재 환경의 공인 IP (121.160.41.205)
}

variable "bgp_asn" {
  description = "BGP ASN for the customer gateway"
  type        = number
  default     = 65000 # [수정 필요] 온프레미스 장비의 BGP ASN
}
