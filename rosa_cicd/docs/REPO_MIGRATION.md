# ROSA Apps Migration Guide

**기존 `03_K8s_Infra`에서 Tekton 전용 `rosa-apps`로 마이그레이션**

---

## 1. 마이그레이션 실행

**주의:** Gitea 토큰이 필요합니다. Gitea 사용자 설정 > 애플리케이션 > 토큰 생성.

```bash
cd /home/ansible/Antigravity/Terraform\(AWS\)/terraform/rosa_cicd

# 토큰 환경변수 설정
export GITEA_TOKEN="your_gitea_token_here"

# 마이그레이션 실행
ansible-playbook playbooks/migrate_repo.yml
```

---

## 2. 결과 확인

**Gitea 접속:** `http://10.2.2.40:3000/ansible/rosa-apps`

**디렉토리 구조:**
```
rosa-apps/
├── apps/              # 소스 코드
│   ├── energy-api/
│   ├── kma-api/
│   └── ...
└── README.md
```

---

## 3. Tekton 설정 확인

`group_vars/rosa.yml`이 자동으로 업데이트되었습니다:
```yaml
git_repo_url: "http://10.2.2.40:3000/ansible/rosa-apps.git"
```

이제 Tekton 파이프라인은 이 새로운 리포지토리를 바라봅니다.
