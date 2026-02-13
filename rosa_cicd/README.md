# ROSA CI/CD Automation Project

**AWS ROSA 클러스터 CI/CD 파이프라인 자동화**

Tekton + ArgoCD + External Secrets + DR Worker

---

## 프로젝트 구조

```
rosa_cicd/
├── playbooks/              # Ansible Playbooks
│   ├── deploy_all.yml      # 전체 통합 실행
│   ├── setup.yml           # CI/CD 설치만
│   └── sync_harbor_to_ecr.yml  # Harbor 동기화만
├── roles/                  # Ansible Roles
│   ├── harbor_sync/        # Harbor → ECR 동기화
│   ├── tekton/             # Tekton Pipelines
│   ├── argocd/             # ArgoCD
│   ├── external_secrets/   # External Secrets Operator
│   └── dr_worker/          # DR Worker Pod
├── inventory/              # Inventory 파일
│   └── hosts.yml
├── group_vars/             # 변수 정의
│   └── rosa.yml
├── docs/                   # 문서
│   └── HARBOR_ECR_SYNC.md
└── README.md
```

---

## 빠른 시작

### 1. 사전 준비
```bash
# ROSA kubeconfig 설정
rosa download kubeconfig -c dr-rosa-cluster
export KUBECONFIG=~/.kube/rosa-config

# Ansible Collection 설치
ansible-galaxy collection install kubernetes.core community.docker

# Harbor 비밀번호 설정
export HARBOR_PASSWORD='Admin123'
```

### 2. 전체 배포 (권장)
```bash
cd /home/ansible/Antigravity/Terraform\(AWS\)/terraform/rosa_cicd

# Harbor → ECR 동기화 + CI/CD 설치
ansible-playbook -i inventory/hosts.yml playbooks/deploy_all.yml
```

### 3. 개별 실행
```bash
# Harbor → ECR 동기화만
ansible-playbook playbooks/sync_harbor_to_ecr.yml

# CI/CD 설치만
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml

# 특정 컴포넌트만
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags tekton
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags argocd
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags dr
```

---

## 설치 컴포넌트

### CI/CD Pipeline
- **Tekton Pipelines** - CI (빌드/푸시)
- **Tekton Dashboard** - UI
- **ArgoCD** - CD (자동 배포)

### Secret 관리
- **External Secrets Operator** - AWS Secrets Manager 연동

### DR 자동화
- **DR Worker Pod** - SQS 기반 자동 Failover

---

## 이미지 관리

### Harbor → ECR 동기화
```
Harbor (10.2.2.40:5000)          ECR (AWS)
library/oauth-api          →     production/oauth-api
library/web-v2-dashboard   →     production/web-v2-dashboard
library/energy-api         →     production/energy-api
library/dr-worker          →     production/dr-worker
... (총 8개)
```

---

## 주요 설정

### 변수 (`group_vars/rosa.yml`)
```yaml
# ROSA Cluster
rosa_cluster_name: dr-rosa-cluster
aws_region: ap-northeast-2

# Namespaces
app_namespace: production

# Harbor
harbor_url: "10.2.2.40:5000"
harbor_username: "admin"

# Applications (8개)
applications:
  - name: oauth-api
  - name: web-v2-dashboard
  - name: energy-api
  - name: dr-worker
  ...
```

---

## 확인 및 접속

### Tekton Dashboard
```bash
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097
# http://localhost:9097
```

### ArgoCD UI
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# https://localhost:8080

# 초기 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### DR Worker 로그
```bash
kubectl logs -n dr-system -l app=dr-worker -f
```

---

## 트러블슈팅

### kubeconfig 오류
```bash
export KUBECONFIG=~/.kube/rosa-config
kubectl get nodes
```

### Harbor 로그인 실패
```bash
export HARBOR_PASSWORD='Admin123'
docker login 10.2.2.40:5000 -u admin -p $HARBOR_PASSWORD
```

### ECR 권한 오류
```bash
aws ecr get-authorization-token --region ap-northeast-2
```

---

## 문서

- [Harbor → ECR 동기화 가이드](docs/HARBOR_ECR_SYNC.md)
- [DR Worker 구현 가이드](/home/ansible/.gemini/antigravity/brain/009a9c00-acfe-4069-a75c-08604ebbc2ae/dr_worker_implementation.md)

---

## 아키텍처

```
Harbor (온프레미스)
    ↓
  동기화
    ↓
ECR (AWS)
    ↓
ROSA Cluster
├── Tekton (CI)
├── ArgoCD (CD)
├── External Secrets (Secret 관리)
└── DR Worker (자동 Failover)
```

---

**프로젝트 상태:** ✅ 프로덕션 준비 완료
