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
  # VPN Configuration
  customer_gateway_ip = var.onprem_ip
  on_prem_cidr        = var.onprem_internal_cidr
  vpn_psk             = var.vpn_psk
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

  cluster_oidc_provider_arn = var.cluster_oidc_provider_arn
  worker_image_url          = var.worker_image_url

  # Health Check Configuration (Default: HTTP/80)
  # If you enable HTTPS on-prem later, change these to "HTTPS" and 443
  health_check_type      = "HTTPS"
  health_check_port      = 443
  alarm_name             = "On-Prem-Disaster-Alarm"
  dr_failover_queue_name = "DR-Failover-Queue"

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

#===============================================================================
# VPN 검증용 EC2 및 IAM (20-ec2)
#===============================================================================
# IAM Role for SSM (키 페어 없이 접속)
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name               = "${var.environment}-EC2RoleForSSM"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.environment}-EC2ProfileForSSM"
  role = aws_iam_role.ssm_role.name
}

# Security Group
resource "aws_security_group" "vpn_test" {
  name   = "${var.environment}-sg-vpn-test"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.onprem_internal_cidr]
    description = "Allow SSH from On-Premise"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.onprem_internal_cidr]
    description = "Allow ICMP from On-Premise"
  }

  egress { # 아웃바운드 전체 허용 (필수)
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.environment}-sg-vpn-test" }
}

# EC2 Instance (Amazon Linux 2023)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "vpn_tester" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = "t3.micro"
  subnet_id            = module.network.private_subnet_ids[0]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.vpn_test.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nmap tcpdump
              EOF

  tags = { Name = "${var.environment}-vpn-tester-ec2" }
}
