pipeline {
    agent any

    options {
        timeout(time: 1, unit: 'HOURS')
        timestamps()
        // 빌드 번호 옆에 설명을 예쁘게 붙여줍니다.
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        choice(name: 'STACK', choices: ['00-global', '10-base-network', '20-net-sec', '30-database', '40-edge', 'all'], description: '💠 배포할 인프라 스택을 선택하세요.')
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: '🛠 실행할 작업을 선택하세요.')
        string(name: 'ENV', defaultValue: 'dr', description: '🌐 환경 이름 (dr, prod, dev 등)')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        AWS_DEFAULT_REGION = 'ap-northeast-2'
        // 시스템 경로를 강제로 주입하여 terraform을 찾을 수 있게 합니다.
        PATH = "/usr/local/bin:/usr/bin:/bin:${env.PATH}"
    }

    stages {
        stage('🚚 Preparation') {
            steps {
                script {
                    currentBuild.displayName = "#${BUILD_NUMBER} [${params.STACK}] - ${params.ACTION}"
                    currentBuild.description = "Environment: ${params.ENV} | Target: ${params.STACK}"
                    
                    echo "========================================================="
                    echo "🚀 ANTIGRAVITY DR INFRASTRUCTURE PIPELINE STARTING..."
                    echo "========================================================="
                    
                    // 테라폼 바이너리 경로 결정 및 자가 설치
                    def tfExists = sh(script: "command -v terraform >/dev/null 2>&1", returnStatus: true) == 0
                    if (tfExists) {
                        env.TF_EXEC = "terraform"
                        echo "✅ [SYSTEM] System Terraform detected."
                    } else {
                        echo "⚠️  [SYSTEM] Terraform not found. Setting up portable version..."
                        sh """
                            mkdir -p bin
                            if [ ! -f bin/terraform ]; then
                                curl -L https://releases.hashicorp.com/terraform/1.10.5/terraform_1.10.5_linux_amd64.zip -o terraform.zip
                                unzip -o terraform.zip -d bin/
                                chmod +x bin/terraform
                                rm terraform.zip
                            fi
                        """
                        env.TF_EXEC = "${WORKSPACE}/bin/terraform"
                        echo "✅ [SYSTEM] Portable Terraform ready at: ${env.TF_EXEC}"
                    }
                    
                    sh "${env.TF_EXEC} --version"
                    echo "📍 TARGET ENV   : ${params.ENV}"
                    echo "📍 OPERATION    : ${params.ACTION}"
                }
            }
        }

        stage('🔍 Terraform Init') {
            steps {
                script {
                    if (params.STACK == 'all') {
                        echo "📦 [INFO] 전체 시스템 초기화 진행 중..."
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            sh "${env.TF_EXEC} init -no-color"
                        }
                    }
                }
            }
        }

        stage('📊 Dry Run (Plan)') {
            steps {
                script {
                    echo "---------------------------------------------------------"
                    echo "📝 인프라 변경 사항 분석 중 (Terraform Plan)..."
                    echo "---------------------------------------------------------"
                    if (params.STACK == 'all') {
                        echo "⚠️  'all' 스택은 전체 배포 스크립트를 통해 진행됩니다."
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            sh "${env.TF_EXEC} plan -out=tfplan -no-color"
                        }
                    }
                }
            }
        }

        stage('🤝 Waiting for Approval') {
            when {
                expression { return params.ACTION != 'plan' }
            }
            steps {
                script {
                    echo "---------------------------------------------------------"
                    echo "🙋 인프라 변경 승인이 필요합니다!"
                    echo "---------------------------------------------------------"
                    input message: "위의 Plan 결과를 확인하셨습니까? '${params.STACK}' 스택을 '${params.ACTION}' 하시겠습니까?", 
                          ok: "🚀 승인 및 실행 (Proceed)"
                }
            }
        }

        stage('⚡ Execution') {
            when {
                expression { return params.ACTION != 'plan' }
            }
            steps {
                script {
                    echo "========================================================="
                    echo "🔥 실제 인프라 변경 작업을 가동합니다: ${params.ACTION}"
                    echo "========================================================="
                    if (params.STACK == 'all') {
                        // TODO: apply_all.sh 내부에서도 TF_EXEC를 쓰도록 수정이 필요할 수 있습니다.
                        if (params.ACTION == 'apply') sh "./scripts/apply_all.sh ${params.ENV}"
                        else if (params.ACTION == 'destroy') sh "./scripts/destroy_all.sh ${params.ENV}"
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            if (params.ACTION == 'apply') sh "${env.TF_EXEC} apply -auto-approve tfplan -no-color"
                            else if (params.ACTION == 'destroy') sh "${env.TF_EXEC} destroy -auto-approve -no-color"
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                echo "========================================================="
                echo "✅ MISSION ACCOMPLISHED: SUCCESS"
                echo "========================================================="
                echo "인프라 작업이 성공적으로 완료되었습니다."
            }
        }
        failure {
            script {
                echo "========================================================="
                echo "❌ MISSION FAILED: ERROR"
                echo "========================================================="
                echo "작업 중 오류가 발생했습니다. 로그를 확인하세요."
            }
        }
        always {
            script {
                echo "🏁 Pipeline Finished."
            }
        }
    }
}
