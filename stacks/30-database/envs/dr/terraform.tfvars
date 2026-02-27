environment       = "dr"
aws_region        = "ap-northeast-2"
project_name      = "antigravity-dr-db"

# RDS
db_instance_class     = "db.t3.medium"
rds_db_password       = "postgres123!" # AWS RDS 비밀번호
onprem_db_password    = "CHANGE_ME"    # 온프레미스 DB 비밀번호 (기존 API 호환용)
db_allocated_storage  = 100
postgres_version      = "13"

# DMS
onprem_db_tailscale_ip = "100.125.39.17"
dms_instance_class     = "dms.t3.medium"

# Tailscale
tailscale_api_key = "tskey-api-kKovKnQ6S611CNTRL-FcgmpU15nBYktwCUguwNBYRVHBJPXW61"
tailnet           = "sungeun6790@gmail.com"

# Bridge
bridge_ami_id        = "ami-0ac22ed9e7ba4d3bd" # Amazon Linux 2023 (ap-northeast-2 기준)
bridge_instance_type = "t3.micro"
