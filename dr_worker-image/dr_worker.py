#!/usr/bin/env python3
"""
DR Worker Pod - Disaster Recovery Automation
SQS 메시지 기반 자동 DR 처리
"""

import os
import sys
import time
import json
import boto3
import logging
import requests
from datetime import datetime

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('dr-worker')

# 환경 변수
AWS_REGION = os.getenv('AWS_REGION', 'ap-northeast-2')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
RDS_INSTANCE_ID = os.getenv('RDS_INSTANCE_ID')
ALB_DNS = os.getenv('ALB_DNS')
VPN_CONNECTION_ID = os.getenv('VPN_CONNECTION_ID')

# AWS 클라이언트
sqs = boto3.client('sqs', region_name=AWS_REGION)
rds = boto3.client('rds', region_name=AWS_REGION)
ec2 = boto3.client('ec2', region_name=AWS_REGION)
cloudwatch = boto3.client('cloudwatch', region_name=AWS_REGION)


class DRWorker:
    """DR 자동화 워커"""
    
    def __init__(self):
        self.running = True
    
    def precheck(self):
        """DR 사전 점검 (dr_precheck.sh 대체)"""
        logger.info("=== DR 사전 점검 시작 ===")
        
        # 1. VPN 상태 확인
        vpn_status = self.check_vpn_status()
        logger.info(f"VPN 상태: {vpn_status}")
        
        # 2. RDS 복제 지연 확인
        replication_lag = self.check_replication_lag()
        logger.info(f"복제 지연: {replication_lag}초")
        
        # 3. 온프레미스 Health Check
        onprem_healthy = self.check_onprem_health()
        logger.info(f"온프레미스 상태: {'정상' if onprem_healthy else '장애'}")
        
        return {
            'vpn_status': vpn_status,
            'replication_lag': replication_lag,
            'onprem_healthy': onprem_healthy
        }
    
    def check_vpn_status(self):
        """VPN 터널 상태 확인"""
        try:
            if not VPN_CONNECTION_ID:
                return 'UNKNOWN'
            
            response = ec2.describe_vpn_connections(
                VpnConnectionIds=[VPN_CONNECTION_ID]
            )
            
            if not response['VpnConnections']:
                return 'NOT_FOUND'
            
            vpn = response['VpnConnections'][0]
            tunnels = vpn.get('VgwTelemetry', [])
            
            # 최소 1개 터널이 UP이면 정상
            up_tunnels = [t for t in tunnels if t['Status'] == 'UP']
            
            if len(up_tunnels) > 0:
                return 'UP'
            else:
                return 'DOWN'
        
        except Exception as e:
            logger.error(f"VPN 상태 확인 실패: {e}")
            return 'ERROR'
    
    def check_replication_lag(self):
        """RDS 복제 지연 확인"""
        try:
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/RDS',
                MetricName='ReplicaLag',
                Dimensions=[
                    {'Name': 'DBInstanceIdentifier', 'Value': RDS_INSTANCE_ID}
                ],
                StartTime=datetime.utcnow().replace(minute=0, second=0, microsecond=0),
                EndTime=datetime.utcnow(),
                Period=300,
                Statistics=['Average']
            )
            
            if response['Datapoints']:
                return response['Datapoints'][-1]['Average']
            else:
                return 0
        
        except Exception as e:
            logger.error(f"복제 지연 확인 실패: {e}")
            return -1
    
    def check_onprem_health(self):
        """온프레미스 Health Check"""
        try:
            # Route53 Health Check 상태 확인
            # 또는 직접 HTTP 요청
            response = requests.get(
                'http://cafekec.shop/healthz/global-status',
                timeout=5
            )
            return response.status_code == 200
        
        except Exception as e:
            logger.error(f"온프레미스 Health Check 실패: {e}")
            return False
    
    def promote_rds(self):
        """RDS Read Replica를 Primary로 승격 (db_promote.sh 대체)"""
        logger.info(f"=== RDS 승격 시작: {RDS_INSTANCE_ID} ===")
        
        try:
            # Read Replica 승격
            response = rds.promote_read_replica(
                DBInstanceIdentifier=RDS_INSTANCE_ID
            )
            
            logger.info(f"RDS 승격 요청 완료: {response['DBInstance']['DBInstanceStatus']}")
            
            # 승격 완료 대기
            waiter = rds.get_waiter('db_instance_available')
            logger.info("RDS 승격 완료 대기 중...")
            
            waiter.wait(
                DBInstanceIdentifier=RDS_INSTANCE_ID,
                WaiterConfig={'Delay': 30, 'MaxAttempts': 40}
            )
            
            logger.info("✅ RDS 승격 완료!")
            return True
        
        except Exception as e:
            logger.error(f"❌ RDS 승격 실패: {e}")
            return False
    
    def postcheck(self):
        """DR 사후 점검 (dr_postcheck.sh 대체)"""
        logger.info("=== DR 사후 점검 시작 ===")
        
        # 1. ALB Health Check
        alb_healthy = self.check_alb_health()
        logger.info(f"ALB 상태: {'정상' if alb_healthy else '장애'}")
        
        # 2. RDS 상태 확인
        rds_status = self.check_rds_status()
        logger.info(f"RDS 상태: {rds_status}")
        
        # 3. ROSA Pod 상태 확인
        # (Kubernetes API 호출 필요)
        
        return {
            'alb_healthy': alb_healthy,
            'rds_status': rds_status
        }
    
    def check_alb_health(self):
        """ALB Health Check"""
        try:
            if not ALB_DNS:
                return False
            
            response = requests.get(
                f'http://{ALB_DNS}/health',
                timeout=10
            )
            return response.status_code == 200
        
        except Exception as e:
            logger.error(f"ALB Health Check 실패: {e}")
            return False
    
    def check_rds_status(self):
        """RDS 인스턴스 상태 확인"""
        try:
            response = rds.describe_db_instances(
                DBInstanceIdentifier=RDS_INSTANCE_ID
            )
            
            if response['DBInstances']:
                return response['DBInstances'][0]['DBInstanceStatus']
            else:
                return 'NOT_FOUND'
        
        except Exception as e:
            logger.error(f"RDS 상태 확인 실패: {e}")
            return 'ERROR'
    
    def process_message(self, message):
        """SQS 메시지 처리"""
        try:
            body = json.loads(message['Body'])
            event_type = body.get('event_type')
            
            logger.info(f"메시지 수신: {event_type}")
            
            if event_type == 'ONPREM_FAILURE':
                # 온프레미스 장애 감지
                logger.warning("🚨 온프레미스 장애 감지!")
                
                # 1. 사전 점검
                precheck_result = self.precheck()
                
                # 2. RDS 승격
                if self.promote_rds():
                    # 3. 사후 점검
                    postcheck_result = self.postcheck()
                    
                    logger.info("✅ DR 전환 완료!")
                    return True
                else:
                    logger.error("❌ DR 전환 실패!")
                    return False
            
            elif event_type == 'MANUAL_FAILOVER':
                # 수동 Failover
                logger.info("수동 Failover 요청")
                return self.promote_rds()
            
            else:
                logger.warning(f"알 수 없는 이벤트 타입: {event_type}")
                return False
        
        except Exception as e:
            logger.error(f"메시지 처리 실패: {e}")
            return False
    
    def run(self):
        """메인 루프"""
        logger.info("DR Worker 시작...")
        logger.info(f"SQS Queue: {SQS_QUEUE_URL}")
        logger.info(f"RDS Instance: {RDS_INSTANCE_ID}")
        
        while self.running:
            try:
                # SQS 메시지 수신
                response = sqs.receive_message(
                    QueueUrl=SQS_QUEUE_URL,
                    MaxNumberOfMessages=1,
                    WaitTimeSeconds=20
                )
                
                messages = response.get('Messages', [])
                
                for message in messages:
                    # 메시지 처리
                    success = self.process_message(message)
                    
                    if success:
                        # 메시지 삭제
                        sqs.delete_message(
                            QueueUrl=SQS_QUEUE_URL,
                            ReceiptHandle=message['ReceiptHandle']
                        )
                        logger.info("메시지 처리 완료 및 삭제")
                    else:
                        logger.error("메시지 처리 실패 (재시도 대기)")
            
            except KeyboardInterrupt:
                logger.info("종료 신호 수신")
                self.running = False
            
            except Exception as e:
                logger.error(f"메인 루프 오류: {e}")
                time.sleep(5)
        
        logger.info("DR Worker 종료")


if __name__ == '__main__':
    # 환경 변수 확인
    if not SQS_QUEUE_URL:
        logger.error("SQS_QUEUE_URL 환경 변수가 설정되지 않았습니다!")
        sys.exit(1)
    
    if not RDS_INSTANCE_ID:
        logger.error("RDS_INSTANCE_ID 환경 변수가 설정되지 않았습니다!")
        sys.exit(1)
    
    # DR Worker 실행
    worker = DRWorker()
    worker.run()
