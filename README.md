# Terraform AWS DR Project Documentation

이 문서는 AWS 기반의 **재해 복구(DR) 시스템**을 구축하기 위한 Terraform 프로젝트의 상세 가이드입니다.
특히 **네트워크 구성**, **VPN 운영**, **도메인(HTTPS) 연결**에 대해 중점적으로 설명합니다.

---

## 1. 네트워크 구성 및 CIDR 전략 (Hybrid Cloud)

이 프로젝트는 **온프레미스(PC5-CICD-OPS)** 를 메인(Primary)으로, **AWS**를 재해 복구(DR) 공간으로 사용하는 **하이브리드 아키텍처**입니다.

| 구분 | 변수명 | 현재 설정값 | 설명 및 사용처 |
| :--- | :--- | :--- | :--- |
| **VPC** | `vpc_cidr` | `10.10.0.0/16` | **AWS 전체 네트워크 공간** (ROSA, RDS, ALB 등) |
| **Public Subnet** | `public_subnets` | `10.10.1.0/24`<br>`10.10.2.0/24` | **외부 통신 구간** (ALB, NAT Gateway) |
| **Private Subnet** | `private_subnets` | `10.10.10.0/24`<br>`10.10.11.0/24` | **내부 격리 구간** (ROSA Worker, RDS) |
| **On-Premise** | `on_prem_cidr` | **`10.2.2.0/24`** | **고객사(PC5-CICD-OPS) 내부 IP 대역** (VPN 라우팅 대상) |

---

## 2. [주의] VPN 연결 및 공인 IP 관리 (Troubleshooting)

### 2-1. 현재 설정된 VPN 정보
*   **Customer Gateway IP**: **`121.160.41.205`** (현재 공인 IP) - 영주님쪽이랑 응찬님쪽도 IP가 같음.
*   **On-Prem CIDR**: **`10.2.2.0/24`**

### 2-2. 🚨 공인 IP 변경 시 대처 방법
가정/소무실 환경(유동 IP) 특성상 IP가 변경되어 VPN이 끊길 수 있습니다. (증상: 온프레미스 ↔ AWS 통신 두절)

1.  **현재 IP 확인**: `curl -s icanhazip.com`
2.  **변수 수정**: `environments/dr/terraform.tfvars` 파일을 엽니다.
    ```hcl
    customer_gateway_ip = "121.160.xx.xx" # 변경된 새 IP 입력
    ```
3.  **적용**: `terraform apply`

---

## 3. [필수] 도메인 연결 및 HTTPS 설정 (가비아)

본 프로젝트는 **`eunschool.shop`** 도메인에 대해 **SSL 인증서 발급부터 HTTPS 적용, DNS Failover 구성까지 100% 자동화**되어 있습니다.
단, 최초 1회 **고객님의 수동 작업(네임서버 변경)** 이 필요합니다.

### 3-1. 작업 순서
1.  **Terraform 배포**: `cd environments/dr` -> `terraform apply` 실행
2.  **네임서버 확인**: 배포 완료 후 출력되는 `name_servers` 값을 확인합니다.
    ```bash
    # 출력 예시
    name_servers = [
      "ns-123.awsdns-45.com",
      "ns-678.awsdns-12.net",
      "ns-901.awsdns-34.org",
      "ns-234.awsdns-56.co.uk",
    ]
    ```
3.  **가비아 설정**:
    *   가비아 홈페이지 접속 -> **My가비아** -> **서비스 관리** -> **도메인 관리**
    *   `eunschool.shop` 선택 -> **네임서버 설정** 클릭
    *   위에서 확인한 4개의 주소로 **모두 변경**합니다. (기존 가비아 네임서버 삭제)
4.  **완료 확인 (자동)**:
    *   Terraform이 자동으로 ACM 인증서를 발급받고 ALB(로드밸런서)에 HTTPS(443)를 적용합니다.
    *   평상시 (`www.eunschool.shop`): **온프레미스 (121.160.xx.xx)** 로 접속
    *   **장애 발생 시**: AWS DR (ALB)로 자동 전환

---

## 4. [할 일] 추가 설정 필요 항목

`environments/dr/variables.tf` 및 `main.tf`에서 아래 내용들을 점검하세요.

*   `onprem_health_check_url`: 온프레미스 서비스 상태 체크 URL (현재 HTTP/80 사용 중. HTTPS 전환 시 `main.tf`의 `health_check_type` 변경 필요)
*   `cluster_oidc_provider_arn`: ROSA 클러스터 생성 후 확인되는 OIDC ARN 입력
*   `worker_image_url`: ECR에 푸시된 DR Worker 이미지 URL 입력

---

## 5. 프로젝트 구조

```
terraform/
├── environments/
│   └── dr/                # [메인] DR 환경 (main.tf, terraform.tfvars)
├── modules/
│   ├── network/           # VPC, VPN (IP 설정)
│   ├── route53/           # 도메인 & ACM 인증서(HTTPS) 자동화
│   ├── alb/               # Load Balancer & 리스너(HTTP/HTTPS)
│   ├── dr_failover/       # 장애 감지 & 복구 로직
│   └── ...
└── README.md              # 이 문서
```
