environment             = "dr"
region                  = "ap-northeast-2"
domain_name             = "cafekec.shop" # TODO: 실제 서비스 도메인으로 변경
primary_target_domain   = "provocatively-ungenerative-kendra.ngrok-free.dev" # TODO: 온프레미스(또는 Primary) Web Endpoint로 변경
openshift_api_url         = "https://api.rosa-single-2a.4klb.p3.openshiftapps.com:443"
openshift_token           = "sha256~4Rur-c9nPMLageuOz7jY__c3vde5xKzRNoe8r-PVgL8"
alarm_email               = "soldesk260113@gmail.com" # TODO: 알람 수신 이메일 변경

ai_rag_image_url        = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/ai-rag:debug-fix13"
auth_chat_api_image_url = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/auth-chat-api:latest"
dr_worker_image_url     = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/dr-worker:latest"
energy_api_image_url    = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/energy-api:latest"
kma_api_image_url       = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/kma-api:latest"
redis_image_url         = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/redis:latest"
web_dash_image_url      = "368352028691.dkr.ecr.ap-northeast-2.amazonaws.com/production/web-v2-dashboard:latest-8"
default_model           = "llama3.2:3b"

kma_authkey          = "MmNnsQppQqGjZ7EKaaKhgQ"
airkorea_service_key = "e7354f71712bb551aa973ec38c763141f796a7ae2129dee32e600105c11d4ad1"
emp_api_key          = "8D4GI7rDQnO4ukBpn4QTbSeT5H9a8eahji7E2td5"
rds_db_password      = "postgres123!"
onprem_ip            = "100.125.39.17"

alb_dns_name           = "ae87d72d5fb934d37a799404f5a1f834-068e86bba564dd2b.elb.ap-northeast-2.amazonaws.com"
alb_zone_id            = "ZIBE1TIR4HY56"
use_cloudfront_only    = true
