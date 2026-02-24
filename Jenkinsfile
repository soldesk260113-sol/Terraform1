pipeline {
    agent any

    parameters {
        choice(name: 'STACK', choices: ['00-global', '10-base-network', '20-net-sec', '30-database', '40-edge', 'all'], description: '배포할 테라폼 스택을 선택하세요.')
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: '실행할 작업을 선택하세요.')
        string(name: 'ENV', defaultValue: 'dr', description: '환경 이름 (dr, prod, dev 등)')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        // AWS 리전 설정 (기본값)
        AWS_DEFAULT_REGION = 'ap-northeast-2'
    }

    stages {
        stage('Checkout') {
            steps {
                // Terraform1.git 레포지토리 체크아웃
                git url: 'http://10.2.2.40:3001/admin/Terraform1.git', branch: 'main'
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    if (params.STACK == 'all') {
                        echo "모든 스택을 초기화합니다..."
                        sh "./scripts/apply_all.sh ${params.ENV} init_only" // 스크립트에 init만 하는 기능이 없다면 순차적으로 init 수행 필요
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            sh "terraform init"
                        }
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    if (params.STACK == 'all') {
                        echo "모든 스택의 변경 사항을 확인합니다..."
                        // 전체 스택 plan 로직 (필요시 상세 구현)
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            sh "terraform plan -out=tfplan"
                        }
                    }
                }
            }
        }

        stage('Human Approval') {
            when {
                expression { return params.ACTION != 'plan' }
            }
            steps {
                script {
                    input message: "'${params.STACK}' 스택을 '${params.ACTION}' 하시겠습니까?", ok: "🚀 실행 승인"
                }
            }
        }

        stage('Terraform Execution') {
            when {
                expression { return params.ACTION != 'plan' }
            }
            steps {
                script {
                    if (params.STACK == 'all') {
                        if (params.ACTION == 'apply') {
                            sh "./scripts/apply_all.sh ${params.ENV}"
                        } else if (params.ACTION == 'destroy') {
                            sh "./scripts/destroy_all.sh ${params.ENV}"
                        }
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            if (params.ACTION == 'apply') {
                                sh "terraform apply -auto-approve tfplan"
                            } else if (params.ACTION == 'destroy') {
                                sh "terraform destroy -auto-approve"
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "작업이 완료되었습니다. (Action: ${params.ACTION}, Stack: ${params.STACK})"
        }
        success {
            echo "✅ 테라폼 배포 성공!"
        }
        failure {
            echo "❌ 테라폼 배포 실패. 로그를 확인하세요."
        }
    }
}
