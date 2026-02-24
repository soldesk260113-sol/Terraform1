project = "terraform"
env     = "dr"

onprem_public_ip = "121.160.41.205" # TODO: 온프레미스 VPN 장비의 공인 IP로 변경
onprem_cidr      = "172.16.0.0/16"  # TODO: 온프레미스 내부망 CIDR로 변경
vpc_cidr        = "10.10.0.0/16"
azs             = ["ap-northeast-2a", "ap-northeast-2c"]
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
