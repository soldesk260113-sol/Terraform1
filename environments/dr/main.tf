# AWS Provider Configuration
provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# 네트워크 모듈: VPC, 서브넷 및 TGW 구성
module "network" {
  source = "../../modules/network"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
  # [참고] VPN 관련 변수 (customer_gateway_ip, bgp_asn)는 modules/network/vpn.tf의 기본값을 사용 중이지만,
  # 환경 변수 설정을 우선하도록 명시적으로 전달합니다.
  customer_gateway_ip = var.customer_gateway_ip
}

# 보안 모듈: 보안 그룹 및 ACL, WAF 설정
module "security" {
  source = "../../modules/security"

  environment = var.environment
  vpc_id      = module.network.vpc_id
  subnet_ids  = module.network.public_subnet_ids
}

# 데이터베이스 모듈: RDS PostgreSQL (DR Read Replica 역할)
module "database" {
  source = "../../modules/database"

  environment        = var.environment
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.security.web_sg_id]
  instance_class     = var.db_instance_class
  db_username        = var.db_username
  db_password        = var.db_password
}

# ROSA 모듈: Red Hat OpenShift on AWS
module "rosa" {
  source = "../../modules/rosa"

  cluster_name      = "${var.environment}-rosa-cluster"
  subnet_ids        = module.network.private_subnet_ids
  worker_node_count = var.dr_mode ? 2 : 0
}

# 스토리지 모듈: DR 데이터/백업용 S3
module "s3" {
  source = "../../modules/s3"
  
  environment = var.environment
  region      = var.region
}

# ECR 모듈: 컨테이너 이미지 레지스트리
module "ecr" {
  source = "../../modules/ecr"
  
  environment = var.environment
}

# ALB 모듈: 애플리케이션 로드 밸런서
module "alb" {
  source = "../../modules/alb"

  environment        = var.environment
  subnet_ids         = module.network.public_subnet_ids
  security_group_ids = [module.security.web_sg_id]
  vpc_id             = module.network.vpc_id
  certificate_arn    = module.route53.certificate_arn
}

# Route53 모듈: DNS 설정 (Failover Routing)
module "route53" {
  source = "../../modules/route53"

  domain_name             = var.domain_name
  alb_dns_name            = module.alb.dns_name
  alb_zone_id             = module.alb.zone_id
  primary_target_domain   = var.primary_target_domain
  primary_health_check_id = module.dr_failover.health_check_id
}

# DR Failover Module: EventBridge, SQS, Health Checks, Worker IAM
module "dr_failover" {
  source = "../../modules/dr_failover"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  environment             = var.environment
  region                  = var.region
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  private_route_table_ids = module.network.private_route_table_ids
  security_group_ids      = [module.security.web_sg_id]

  primary_target_domain     = var.primary_target_domain
  dr_failover_queue_name    = var.dr_failover_queue_name
  cluster_oidc_provider_arn = var.cluster_oidc_provider_arn
  worker_image_url          = var.worker_image_url

  # Health Check Configuration (Default: HTTP/80)
  # If you enable HTTPS on-prem later, change these to "HTTPS" and 443
  health_check_type = "HTTP"
  health_check_port = 80

  rds_cluster_identifier = module.database.db_instance_id
  target_deployment_name = "web-service"
}

# Generate Kubernetes Manifest for DR Worker
resource "local_file" "dr_worker_manifest" {
  filename = "${path.module}/dr-failover-worker.yaml"
  content  = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dr-failover-worker
  namespace: dr-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dr-worker
  template:
    metadata:
      labels:
        app: dr-worker
    spec:
      serviceAccountName: dr-worker-sa
      containers:
      - name: worker
        image: ${var.worker_image_url}
        imagePullPolicy: Always
        env:
        - name: SQS_URL
          value: "${module.dr_failover.sqs_queue_url}"
        - name: RDS_ID
          value: "${module.database.db_instance_id}"
        - name: TARGET_DEPLOYMENT
          value: "web-service"
        - name: AWS_REGION
          value: "${var.region}"
YAML
}
