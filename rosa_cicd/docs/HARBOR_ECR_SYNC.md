# Harbor to ECR Image Sync

**목적:** 온프레미스 Harbor(`10.2.2.40:5000`)의 이미지를 AWS ECR로 자동 복제

---

## 사용 방법

### 1. 사전 준비
```bash
# Docker 설치 확인
docker --version

# AWS CLI 설정 확인
aws sts get-caller-identity

# Ansible Docker Collection 설치
ansible-galaxy collection install community.docker

# Harbor 비밀번호 환경변수 설정 (권장)
export HARBOR_PASSWORD='your-harbor-password'
```

### 2. Playbook 실행
```bash
cd /home/ansible/Antigravity/Terraform\(AWS\)/terraform/rosa_cicd

# 환경변수로 Harbor 비밀번호 전달 (권장)
export HARBOR_PASSWORD='Admin123'
ansible-playbook playbooks/sync_harbor_to_ecr.yml

# 또는 직접 변수 전달
ansible-playbook playbooks/sync_harbor_to_ecr.yml -e harbor_password='Admin123'

# 로컬 이미지 정리 포함
ansible-playbook playbooks/sync_harbor_to_ecr.yml -e cleanup_local_images=true
```

### 3. 확인
```bash
# ECR 이미지 목록 확인
aws ecr describe-images --repository-name production/web-v2 --region ap-northeast-2
aws ecr describe-images --repository-name production/energy-api --region ap-northeast-2
```

---

## 이미지 매핑

| Harbor 이미지 | ECR 리포지토리 |
| :--- | :--- |
| `library/oauth-api` | `production/oauth-api` |
| `library/web-v2-dashboard` | `production/web-v2-dashboard` |
| `library/integrated-dashboard` | `production/integrated-dashboard` |
| `library/map-api` | `production/map-api` |
| `library/energy-api` | `production/energy-api` |
| `library/my-web` | `production/my-web` |
| `library/kma-api` | `production/kma-api` |

---

## 자동화 (Cron)

### 정기 동기화 설정
```bash
# Cron 등록 (매일 새벽 2시)
crontab -e

# 추가
0 2 * * * cd /home/ansible/Antigravity/Terraform\(AWS\)/terraform/rosa_cicd && ansible-playbook playbooks/sync_harbor_to_ecr.yml >> /var/log/harbor-ecr-sync.log 2>&1
```

---

## 커스터마이징

### 이미지 추가
`playbooks/sync_harbor_to_ecr.yml` 파일 수정:
```yaml
images_to_sync:
  - name: "library/new-image"
    ecr_repo: "production/new-image"
```

### 특정 태그 동기화
```yaml
- name: Pull specific tag
  docker_image:
    name: "{{ harbor_url }}/{{ item.name }}"
    tag: "v1.0.0"  # 특정 태그
    source: pull
```

---

## 트러블슈팅

### Harbor 접속 불가
```bash
# Harbor 연결 확인
curl http://10.2.2.40:5000/v2/_catalog

# Docker에서 insecure registry 설정
sudo vi /etc/docker/daemon.json
{
  "insecure-registries": ["10.2.2.40:5000"]
}
sudo systemctl restart docker
```

### ECR 권한 오류
```bash
# IAM 권한 확인
aws ecr get-authorization-token --region ap-northeast-2
```

### 이미지 Pull 실패
```bash
# Harbor 이미지 목록 확인
curl http://10.2.2.40:5000/v2/library/nodejs-api/tags/list
```
