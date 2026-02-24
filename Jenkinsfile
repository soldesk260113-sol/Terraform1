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
                    echo "📍 TARGET ENV   : ${params.ENV}"
                    echo "📍 TARGET STACK : ${params.STACK}"
                    echo "📍 OPERATION    : ${params.ACTION}"
                    echo "========================================================="
                }
                git url: 'http://10.2.2.40:3001/admin/Terraform1.git', branch: 'main'
            }
        }

        stage('🔍 Terraform Init') {
            steps {
                script {
                    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
                        if (params.STACK == 'all') {
                            echo "📦 [INFO] 전체 시스템 초기화 진행 중..."
                            // 여기에 순차적 init 로직 추가 가능
                        } else {
                            dir("stacks/${params.STACK}/envs/${params.ENV}") {
                                sh "terraform init -no-color"
                            }
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
                            sh "terraform plan -out=tfplan -no-color"
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
                        if (params.ACTION == 'apply') sh "./scripts/apply_all.sh ${params.ENV}"
                        else if (params.ACTION == 'destroy') sh "./scripts/destroy_all.sh ${params.ENV}"
                    } else {
                        dir("stacks/${params.STACK}/envs/${params.ENV}") {
                            if (params.ACTION == 'apply') sh "terraform apply -auto-approve tfplan -no-color"
                            else if (params.ACTION == 'destroy') sh "terraform destroy -auto-approve -no-color"
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
