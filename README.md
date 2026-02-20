# Terraform Project — DR Infrastructure (AWS)

AWS 기반 DR(Disaster Recovery) 인프라를 Terraform으로 관리하는 프로젝트입니다.
**레이어드 아키텍처**(`stacks`)를 사용하여 의존성과 State를 격리합니다.

---

## 디렉터리 구조

```
terraform/
├── stacks/                   # ✅ 메인 인프라 (레이어드 아키텍처)
│   ├── 00-global/            # [L0] ECR 레포지토리, S3 DR 백업 버킷
│   ├── 10-base-network/      # [L1] VPC, 서브넷, IGW, NAT GW, 라우팅
│   ├── 20-net-sec/           # [L2] Site-to-Site VPN, Security Group
│   ├── 30-database/          # [L3] RDS (Aurora/PostgreSQL)
│   └── 40-edge/              # [L4] ALB, Route 53 Failover, DR 자동화 로직
│
├── rosa_cicd/                # ROSA 클러스터 CI/CD (Ansible 플레이북)
│                             #   Tekton, ArgoCD, External Secrets 설정
├── dr_worker-image/          # DR Worker 컨테이너 소스
│                             #   Dockerfile + dr_worker.py (자동 페일오버)
├── scripts/                  # 일괄 실행 스크립트
│   ├── apply_all.sh          #   전체 스택 순차 apply
│   └── destroy_all.sh        #   전체 스택 역순 destroy
└── README.md
```

---

## 스택 설명

| 스택 | 역할 | 환경 |
|------|------|------|
| `00-global` | ECR 레포지토리(8개), S3 DR 백업 버킷 | dr |
| `10-base-network` | VPC, 서브넷, 라우팅 테이블, NAT GW | dr |
| `20-net-sec` | 온프레미스↔AWS VPN, Security Group | dr |
| `30-database` | RDS (Aurora/PostgreSQL) | dr |
| `40-edge` | ALB(HTTPS), Route 53 Failover DNS, DR 자동화 | dr |

> 각 스택은 `envs/dr/` 아래에 재해복구 환경 설정을 가집니다.  
> 스택 간 의존성은 S3 기반 `terraform_remote_state`로 참조합니다.

---

## 사용법

### 수동 실행
```bash
cd stacks/<stack>/envs/dr
terraform init
terraform plan
terraform apply
```

### 스크립트 실행 (권장)

**전체 apply** (의존성 순서대로):
```bash
./scripts/apply_all.sh dr
# 실행 순서: 00-global → 10-base-network → 20-net-sec → 30-database → 40-edge
```

**전체 destroy** (역순):
```bash
./scripts/destroy_all.sh dr
# 실행 순서: 40-edge → 30-database → 20-net-sec → 10-base-network → 00-global
```

---

## 주요 구성 요소

### ROSA 클러스터 설정 (CI/CD)
Terraform으로 인프라 배포 후, ROSA 클러스터 내부 설정을 위해 Ansible을 사용합니다.

1. **ROSA 접속 정보 설정**: `rosa_cicd/inventory/hosts.yml` 파일에 API URL 등 입력.
2. **Playbook 실행**:
   ```bash
   cd rosa_cicd
   ansible-playbook -i inventory/hosts.yml playbooks/deploy_all.yml
   ```
   > **기능**: Harbor-ECR 이미지 동기화, Tekton/ArgoCD 설치, External Secrets 설정, DR Worker 배포

### DR Worker 이미지 빌드
DR 자동화 파드(`dr-worker`)가 사용할 이미지를 빌드하여 ECR에 푸시해야 합니다.

```bash
cd dr_worker-image
# 1. ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com

# 2. 빌드 및 푸시
docker build -t <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/production/dr-worker:latest .
docker push <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/production/dr-worker:latest
```

---

## 재해복구(DR) 시나리오 구성

| 구성 요소 | 스택 | 기술 상세 |
|-----------|------|------|
| 네트워크 | `10-base-network` | VPC 10.10.0.0/16, 전용 서브넷 |
| 컨테이너 레지스트리 | `00-global` | ECR (이미지 영구 보관) |
| S3 백업 | `00-global` | 버킷명: `dr-backup-ap-northeast-2` |
| VPN 연결 | `20-net-sec` | AWS S2S VPN (VGW 기반) |
| 트래픽 진입 / DNS | `40-edge` | ALB + Route 53 Failover (Active-Passive) |
| 데이터베이스 | `30-database` | Aurora/PostgreSQL (Global Database 혹은 Replica) |
| 자동 장애 조치 | `40-edge` | EventBridge + SQS + DR Worker (Pod) |
