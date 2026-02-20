# Terraform Project — DR Infrastructure (AWS)

AWS 기반 DR(Disaster Recovery) 인프라를 Terraform으로 관리하는 프로젝트입니다.
**레이어드 아키텍처**(`stacks`)를 사용하여 의존성과 State를 격리합니다.

---

## 디렉터리 구조

```
terraform/
├── stacks/                   # ✅ 메인 인프라 (레이어드 아키텍처)
│   ├── 00-base-network/      # [L0] VPC, 서브넷, IGW, NAT GW, 라우팅
│   ├── 05-global/            # [L1] ECR 레포지토리, S3 DR 백업 버킷
│   ├── 10-net-sec/           # [L2] Site-to-Site VPN, Security Group
│   ├── 20-edge/              # [L3] ALB, Route53 Failover, DR 자동화
│   └── 30-database/          # [L4] RDS (DR Read Replica)
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
| `00-base-network` | VPC, 서브넷, 라우팅 테이블 | dev, dr |
| `05-global` | ECR 레포지토리(8개), S3 DR 백업 버킷 | dr |
| `10-net-sec` | 온프레미스↔AWS VPN, Security Group | dev, dr |
| `20-edge` | ALB(HTTPS), Route53 Failover DNS, DR 자동화 | dev, dr |
| `30-database` | RDS Read Replica (DR 동기화) | dr |

> 각 스택은 `envs/<환경>/` 아래에 환경별 설정을 가집니다.  
> 스택 간 의존성은 `terraform_remote_state`로 참조합니다.

---

## 사용법

### 수동 실행
```bash
cd stacks/<stack>/envs/<env>
terraform init
terraform plan
terraform apply
```

### 스크립트 실행 (권장)

**전체 apply** (의존성 순서대로):
```bash
./scripts/apply_all.sh dr
# 순서: 00 → 05 → 10 → 20 → 30
```

./scripts/destroy_all.sh dr
# 순서: 30 → 20 → 10 → 05 → 00
```

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

### 사전 요구사항 (tfvars)
`.gitignore` 설정에 의해 `terraform.tfvars` 파일은 커밋되지 않습니다. 각 스택의 `envs/<env>/` 디렉터리에 `terraform.tfvars` 파일을 생성하고 필요한 변수(DB 비밀번호, IP 주소 등)를 입력해야 합니다.

---

## DR 환경 구성

| 구성 요소 | 스택 | 내용 |
|-----------|------|------|
| 네트워크 | `00-base-network` | VPC 10.10.0.0/16, 서브넷 |
| 컨테이너 레지스트리 | `05-global` | ECR (8개 서비스 이미지) |
| S3 백업 | `05-global` | DR 백업 버킷 (버전관리 + 암호화) |
| VPN 연결 | `10-net-sec` | Libreswan 기반 Site-to-Site VPN |
| 트래픽 진입 | `20-edge` | ALB + Route53 Failover |
| DB 복제 | `30-database` | RDS Read Replica |
| ROSA 클러스터 | - | `rosa` CLI로 직접 관리 |
