# Local Tekton Environment Setup

**ROSA 클러스터 없이 로컬(10.2.2.40)에서 Tekton 테스트하기**

---

## 1. Docker 컨테이너 실행 (K3s)

10.2.2.40 서버에서 실행합니다:

```bash
# Tekton 실행 (K3s 포함)
docker run --name tekton-local \
  --privileged \
  -p 9097:9097 \
  -d rancher/k3s:v1.24.4-k3s1 server --disable traefik
```

## 2. Kubeconfig 설정

```bash
# Kubeconfig 가져오기
docker cp tekton-local:/etc/rancher/k3s/k3s.yaml ~/.kube/config-tekton
sed -i 's/127.0.0.1/10.2.2.40/g' ~/.kube/config-tekton

# 환경변수 설정
export KUBECONFIG=~/.kube/config-tekton
```

## 3. Tekton 설치

Ansible Playbook을 재사용하여 설치합니다:

```bash
cd /home/ansible/Antigravity/Terraform\(AWS\)/terraform/rosa_cicd

# Tekton만 설치
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags tekton \
  -e "kubeconfig=~/.kube/config-tekton"
```

## 4. 접속 방법

브라우저에서 접속:
- URL: `http://10.2.2.40:9097`

---

## 5. 파이프라인 실행

1. **Pipelines** 메뉴 클릭
2. `build-and-push` 선택
3. **Start** 클릭
4. 파라미터 확인:
   - Git URL: `http://10.2.2.70:3000/ansible/web-v2.git`
   - Image Name: `production/web-v2`
5. **Run** 클릭!
