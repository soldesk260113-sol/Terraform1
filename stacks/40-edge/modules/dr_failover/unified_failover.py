import json
import boto3
import os
import logging
import urllib.request
import urllib.error
import ssl
from datetime import datetime, timezone

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS 클라이언트 초기화
dms = boto3.client('dms')
rds = boto3.client('rds')

def promote_rds(rds_instance_id):
    """RDS 읽기 전용 복제본을 기본 인스턴스로 승격합니다."""
    if not rds_instance_id or rds_instance_id == "dr-placeholder-db":
        logger.info("유효한 RDS_INSTANCE_ID가 제공되지 않았습니다. 승격을 건너뜁니다.")
        return False
    
    logger.info(f"RDS 읽기 전용 복제본 승격 중: {rds_instance_id}")
    try:
        rds.promote_read_replica(DBInstanceIdentifier=rds_instance_id)
        return True
    except Exception as e:
        logger.error(f"RDS 승격 중 오류 발생: {e}")
        return False

def check_failback_status(forward_arn, reverse_arn):
    """복구(Failback)가 가능한 상태인지 확인하고 조치를 취합니다."""
    try:
        tasks = dms.describe_replication_tasks(
            Filters=[{'Name': 'replication-task-arn', 'Values': [forward_arn, reverse_arn]}]
        )['ReplicationTasks']
        f_task = next(t for t in tasks if t['ReplicationTaskArn'] == forward_arn)
        r_task = next(t for t in tasks if t['ReplicationTaskArn'] == reverse_arn)
    except Exception as e:
        logger.error(f"DMS 태스크 정보를 가져오지 못했습니다: {str(e)}")
        return {"status": "dms_api_error"}

    f_status = f_task['Status']
    r_status = r_task['Status']
    
    # [단계 A] 역방향 태스크 상태 및 동기화 확인
    if r_status == 'running':
        stats = r_task.get('ReplicationTaskStats', {})
        latency = stats.get('CDCLatencySource')
        start_time = r_task.get('ReplicationTaskStartDate')
        uptime = (datetime.now(timezone.utc) - start_time).total_seconds() if start_time else 0
        
        logger.info(f"모니터링 - 역방향 가동 시간: {uptime:.1f}초, 지연 시간(Latency): {latency}")

        # 1. 멈춤(Stuck) 복구 로직: 60초 후에도 Latency가 None인 경우
        if uptime > 60 and latency is None:
            logger.warning("!!! 지연 시간 감지 불가: 역방향 태스크가 멈춰 있습니다. 강제 재시작 중...")
            try: dms.stop_replication_task(ReplicationTaskArn=reverse_arn)
            except: pass
            dms.start_replication_task(ReplicationTaskArn=reverse_arn, StartReplicationTaskType='start-replication')
            return {"status": "force_restarting_reverse"}

        # 2. 동기화 완료 로직: Latency가 10초 미만인 경우
        if latency is not None and latency < 10:
            if f_status in ['stopped', 'failed', 'ready']:
                logger.info("!!! 동기화 안정화: 복구를 위해 역방향 태스크 중지 중...")
                try:
                    dms.stop_replication_task(ReplicationTaskArn=reverse_arn)
                    return {"status": "stopping_reverse"}
                except Exception as e:
                    logger.error(f"역방향 태스크 중지 실패: {e}")

    # [단계 B] 복구 전환: 역방향 중지됨 -> 정방향 시작
    if r_status in ['stopped', 'ready'] and f_status in ['stopped', 'failed', 'ready']:
        if f_status != 'starting':
            logger.info("!!! 역방향 안전 중지됨: 정방향 태스크 재시작(복구) 시작 !!!")
            try:
                dms.start_replication_task(ReplicationTaskArn=forward_arn, StartReplicationTaskType='resume-processing')
                return {"status": "failback_complete"}
            except Exception as e:
                logger.warning(f"정방향 태스크 재개 실패, 전체 복제 시도: {e}")
                try:
                    dms.start_replication_task(ReplicationTaskArn=forward_arn, StartReplicationTaskType='start-replication')
                    return {"status": "failback_complete_full_load"}
                except Exception as e2:
                    logger.error(f"정방향 태스크 시작 실패: {e2}")

    return {"status": "monitoring_complete"}

def lambda_handler(event, context):
    """장애 조치(Failover) 및 복구(Failback)를 위한 메인 오케스트레이터."""
    logger.info(f"이벤트 수신: {json.dumps(event)}")
    
    # 환경 변수 로드
    forward_arn = os.environ.get('FORWARD_TASK_ARN', '').strip()
    reverse_arn = os.environ.get('REVERSE_TASK_ARN', '').strip()
    rds_instance = os.environ.get('RDS_INSTANCE_ID')
    
    if not forward_arn or not reverse_arn:
        return {"status": "error", "message": "DMS ARNs missing"}

    source = event.get("source", "")
    detail_type = event.get("detail-type", "")

    # --- 액션 1: 장애 상태 변화 트리거 (SQS를 통한 CloudWatch 알람) ---
    if "Records" in event:
        try:
            sqs_record = event['Records'][0]
            eb_event = json.loads(sqs_record['body'])
            detail = eb_event.get('detail', {})
            alarm_name = detail.get('alarmName', '')
            state = detail.get('state', {}).get('value', '')
            primary_alarm = os.environ.get('PRIMARY_ALARM_NAME')

            if alarm_name == primary_alarm:
                # 상태가 ALARM인 경우 -> 장애 조치 실행
                if state == "ALARM":
                    logger.info(f"!!! 온프레미스 장애 감지 (ALARM): 장애 조치 조작 시작 !!!")
                    promote_rds(rds_instance)
                    
                    try:
                        dms.stop_replication_task(ReplicationTaskArn=forward_arn)
                    except: pass
                    try:
                        dms.start_replication_task(ReplicationTaskArn=reverse_arn, StartReplicationTaskType='resume-processing')
                    except Exception as e:
                        logger.warning(f"역방향 재개 실패, 전체 복제 시도: {str(e)}")
                        try: dms.start_replication_task(ReplicationTaskArn=reverse_arn, StartReplicationTaskType='start-replication')
                        except: pass
                    
                    return {"status": "failover_initiated"}

                # 상태가 OK인 경우 -> 즉시 복구 가능성 확인 시작
                elif state == "OK":
                    logger.info(f"!!! 온프레미스 복구 감지 (OK): 복구 동기화 확인 시작 !!!")
                    return check_failback_status(forward_arn, reverse_arn)

            return {"status": "alarm_ignored", "state": state}
        except Exception as e:
            logger.error(f"알람 이벤트 처리 중 오류: {e}")
            return {"status": "error", "message": str(e)}

    # --- 액션 2: DMS 상태 변경 (이중화된 장애 조치) ---
    if source == "aws.dms":
        detail = event.get('detail', {})
        status = detail.get('status', '').lower()
        resources = event.get('resources', [])

        if any(forward_arn.lower() in res.lower() for res in resources):
            if status in ['stopped', 'failed']:
                logger.warning(f"!!! 정방향 태스크 이벤트 장애 감지 ({status}): 역방향 즉시 가동 !!!")
                try:
                    dms.start_replication_task(ReplicationTaskArn=reverse_arn, StartReplicationTaskType='resume-processing')
                except:
                    try: dms.start_replication_task(ReplicationTaskArn=reverse_arn, StartReplicationTaskType='start-replication')
                    except: pass
                return {"status": "failover_initiated_by_dms_event"}
        
        return {"status": "dms_event_logged"}

    # --- 액션 3:주기적 복구 모니터링 (1분 주기) ---
    if source == "aws.events" and detail_type != "CloudWatch Alarm State Change":
        logger.info("주기적 복구 상태 체크 중...")
        return check_failback_status(forward_arn, reverse_arn)

    return {"status": "ignored_event"}
