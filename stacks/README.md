# 🏗️ Antigravity Infrastructure Stacks (Terraform)

이 디렉토리는 **Antigravity** 프로젝트의 인프라를 논리적 계층으로 분리하여 관리하는 Terraform 스택들로 구성되어 있습니다. 각 스택은 독립적인 상태(State)를 가지며, 레이어드 아키텍처를 통해 종속성을 관리합니다.

---

## 📂 계층 구조 (Layered Architecture)

```text
stacks/
├── 00-global/          # [L0] 전역 리소스
│   ├── envs/dr/        # DR 환경 설정
│   └── modules/        # ecr, s3 (State Backend)
├── 10-base-network/    # [L1] 네트워크 기초
│   ├── envs/dr/
│   └── modules/        # vpc (VPC, Subnet, IGW/NAT)
├── 20-net-sec/         # [L2] 보안 및 연결
│   ├── envs/dr/
│   └── modules/        # security_sg, s2s_vpn_vgw (VPN)
├── 30-database/        # [L3] 데이터 계층
│   ├── envs/dr/
│   └── modules/        # rds, dms, dms_automation, s3_pgbackrest
└── 40-edge/            # [L4] 접점 및 DR 자동화
    ├── envs/dr/
    └── modules/        # route53 (DNS/Health), dr_failover (Lambda)
```

| 계층 | 스택명 | 주요 리소스 및 역할 | 비고 |
|:---:|---|---|---|
| **L0** | [**00-global**](./00-global) | S3(State Backend), ECR(Image Registry) | 초기 부트스트랩 |
| **L1** | [**10-base-network**](./10-base-network) | VPC, Subnets, Internet Gateway | 네트워크 기본 토대 |
| **L2** | [**20-net-sec**](./20-net-sec) | Security Groups, S2S VPN, Virtual Private Gateway | 보안 및 경로 설정 |
| **L3** | [**30-database**](./30-database) | RDS(PostgreSQL), DMS(Data Migration), pgBackRest, Tailscale | 데이터 저장 및 동기화 |
| **L4** | [**40-edge**](./40-edge) | Route 53, CloudFront, WAF, DR Failover Automation | 퍼블릭 엔드포인트 및 DR |

---

## 🛠️ 스택 상세 설명

### 🌐 [00-global](./00-global)
전역적으로 사용되는 기본 인프라입니다.
- **ecr**: 애플리케이션 이미지 저장을 위한 Container Registry.
- **s3**: Terraform Remote State 저장을 위한 Backend 버킷.

### 🛣️ [10-base-network](./10-base-network)
AWS 환경의 통신을 담당하는 핵심 네트워크입니다.
- **vpc**: 표준적인 Public/Private 서브넷 구조를 가진 가상 네트워크 공간.

### 🛡️ [20-net-sec](./20-net-sec)
인프라의 보안 계층입니다.
- **security_sg**: 리소스 간 트래픽 제어를 위한 보안 그룹.
- **s2s_vpn_vgw**: 온프레미스와 AWS 간의 보안 연결(Site-to-Site VPN).

### 🐘 [30-database](./30-database)
데이터 계층으로, 고가용성 및 재해 복구(DR)를 고려하여 설계되었습니다.
- **rds**: PostgreSQL 데이터베이스 인스턴스.
- **dms & dms_automation**: 온프레미스와 클라우드 간 실시간 데이터 복제 및 자동화.
- **s3_pgbackrest**: DB 백업 데이터의 영구 저장을 위한 S3 연동.
- **tailscale_bridge**: 하이브리드 클라우드 프라이빗 통신을 위한 오버레이 네트워크.

### 🚀 [40-edge](./40-edge)
사용자 접점 및 재해 복구 자동화의 핵심부입니다.
- **route53**: 전역 DNS 관리 및 헬스체크 기반 Failover.
- **cloudfront & waf**: CDN 가속 및 웹 보안(WAF) 통합.
- **dr_failover**: 장애 감지 시 람다를 통한 RDS 승격 및 트래픽 자동 전환 로직.

---

## 🚦 실행 가이드 (Execution Order)

새로운 환경 구축 시 아래 순서대로 배포를 진행하는 것을 권장합니다:
1. `00-global` -> 2. `10-base-network` -> 3. `20-net-sec` -> 4. `30-database` -> 5. `40-edge`

```bash
# 예시 실행
cd 10-base-network/envs/dr
terraform init
terraform apply
```

---
**📅 Last Updated**: 2026-02-26
**👤 Maintainer**: Antigravity SRE Team
