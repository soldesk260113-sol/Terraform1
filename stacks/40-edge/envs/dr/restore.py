import re

content_to_write = """
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/10-base-network/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "net_sec" {
  backend = "s3"
  config = {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/20-net-sec/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/30-database/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id                  = data.terraform_remote_state.base.outputs.vpc_id
  public_subnet_ids       = data.terraform_remote_state.base.outputs.public_subnet_ids
  private_subnet_ids      = data.terraform_remote_state.base.outputs.private_subnet_ids
  private_route_table_ids = data.terraform_remote_state.base.outputs.private_route_table_ids

  security_group_ids      = [aws_security_group.vpce.id]
  db_instance_id          = "antigravity-dr-db-rds" # data.terraform_remote_state.database.outputs.db_instance_id 가 비정상적인 ID를 반환하고 있어 하드코딩으로 우회
  db_instance_address     = data.terraform_remote_state.database.outputs.rds_endpoint
}

data "aws_vpc" "selected" {
  id = local.vpc_id
}

resource "aws_security_group" "vpce" {
  name        = "${var.environment}-vpce-sg"
  description = "Security group for VPC Endpoints allowing worker nodes to pull images"
  vpc_id      = local.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}


# DR Failover Module (Lambda Automation)
module "dr_failover" {
  source = "../../modules/dr_failover"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  environment             = var.environment
  region                  = var.region
  vpc_id                  = local.vpc_id
  subnet_ids              = local.private_subnet_ids
  private_route_table_ids = local.private_route_table_ids
  security_group_ids      = local.security_group_ids

  primary_target_domain     = var.primary_target_domain
  alarm_name                = module.route53.failover_alarm_name
  openshift_api_url         = var.openshift_api_url
  openshift_token           = var.openshift_token
  
  rds_cluster_identifier = local.db_instance_id

  # Unified Failover/Failback DMS Integration
  forward_task_arn = data.terraform_remote_state.database.outputs.forward_task_arn
  reverse_task_arn = data.terraform_remote_state.database.outputs.reverse_task_arn
  onprem_host      = var.onprem_ip
}

# Route 53 & Health Checks
module "route53" {
  source = "../../modules/route53"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name             = var.domain_name
  primary_target_domain   = var.primary_target_domain
  primary_health_check_id = var.primary_health_check_id
  alb_dns_name           = var.alb_dns_name
  alb_zone_id            = var.alb_zone_id
  onprem_ip               = var.onprem_ip
  environment             = var.environment
  alarm_email             = var.alarm_email
}
# Note: ROSA ALB is actually an NLB, which doesn't support Regional WAF.
# WAF should be associated with CloudFront instead.

# --------------------------------------------------------------------------------
# OpenShift (Kubernetes) Workloads
# --------------------------------------------------------------------------------

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}


# resource "kubernetes_secret" "ecr_secret" {
#   metadata {
#     name = "ecr-secret"
#     namespace = kubernetes_namespace.production.metadata[0].name
#   }
#   
#   type = "kubernetes.io/dockerconfigjson"
# }

resource "kubernetes_deployment" "redis" {
  metadata {
    name = "redis"
    namespace = kubernetes_namespace.production.metadata[0].name
    labels = {
      app = "redis"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis"
      }
    }
    template {
      metadata {
        labels = {
          app = "redis"
        }
      }
      spec {
        container {
          name  = "redis"
          image = var.redis_image_url
          image_pull_policy = "Always"
          args = ["--stop-writes-on-bgsave-error", "no"]
          port {
            container_port = 6379
          }
        }
        image_pull_secrets {
          name = "ecr-secret"
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name = "redis"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    selector = {
      app = "redis"
    }
    port {
      port        = 6379
      target_port = 6379
    }
  }
}



resource "kubernetes_deployment" "energy_api" {
  metadata {
    name = "energy-api"
    namespace = kubernetes_namespace.production.metadata[0].name
    labels = {
      app = "energy-api"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "energy-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "energy-api"
        }
      }
      spec {
        container {
          name  = "energy-api"
          image = var.energy_api_image_url
          image_pull_policy = "Always"
          env {
            name  = "NODE_ENV"
            value = "production"
          }
          env {
            name  = "DB_HOST"
            value = local.db_instance_address
          }
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          env {
            name  = "DB_NAME"
            value = "appdb"
          }
          env {
            name  = "DB_SCHEMA"
            value = "api"
          }
          env {
            name  = "DB_USER"
            value = "svc_api"
          }
          env {
            name  = "DB_PASSWORD"
            value = var.rds_db_password
          }
          env {
            name  = "DB_SSLMODE"
            value = "disable"
          }
           env {
            name  = "REDIS_HOST"
            value = "redis"
          }
          env {
            name  = "REDIS_PORT"
            value = "6379"
          }
          env {
            name  = "REDIS_DB"
            value = "0"
          }
          env {
            name  = "REDIS_PASSWORD"
            value = ""
          }
          env {
            name  = "REDIS_PREFIX"
            value = "energy"
          }
          env {
            name  = "EMP_API_KEY"
            value = var.emp_api_key
          }
          env {
            name  = "DATA_GO_KR_SERVICE_KEY"
            value = var.airkorea_service_key
          }
          env {
            name  = "KPX_ODCLOUD_DATASET_URL"
            value = "https://api.odcloud.kr/api/15040818/v1/uddi:0873d163-4ed7-49f9-bf95-8eb5c7e35fad"
          }
          env {
            name  = "KPX_CACHE_TTL"
            value = "600"
          }
          env {
            name  = "TZ"
            value = "Asia/Seoul"
          }
        }
        image_pull_secrets {
          name = "ecr-secret"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "kma_api" {
  metadata {
    name = "kma-api"
    namespace = kubernetes_namespace.production.metadata[0].name
    labels = {
      app = "kma-api"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "kma-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "kma-api"
        }
      }
      spec {
        container {
          name  = "kma-api"
          image = var.kma_api_image_url
          image_pull_policy = "Always"
          env {
            name  = "KMA_AUTHKEY"
            value = var.kma_authkey
          }
          env {
            name  = "AIRKOREA_SERVICE_KEY"
            value = var.airkorea_service_key
          }
          env {
            name  = "DB_HOST"
            value = local.db_instance_address
          }
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          env {
            name  = "DB_NAME"
            value = "appdb"
          }
          env {
            name  = "DB_SCHEMA"
            value = "api"
          }
          env {
            name  = "DB_USER"
            value = "svc_api"
          }
          env {
            name  = "DB_PASSWORD"
            value = var.rds_db_password
          }
          env {
            name  = "DB_SSLMODE"
            value = "disable"
          }
          env {
            name  = "REDIS_HOST"
            value = "redis"
          }
          env {
            name  = "REDIS_PORT"
            value = "6379"
          }
          env {
            name  = "REDIS_PREFIX"
            value = "weather"
          }
          env {
            name  = "REDIS_TTL_ULTRA_SECONDS"
            value = "600"
          }
          env {
            name  = "REDIS_TTL_SHORT_SECONDS"
            value = "3600"
          }
          env {
            name  = "REDIS_PREFIX_DUST"
            value = "dust"
          }
          env {
            name  = "REDIS_TTL_DUST_SECONDS"
            value = "1800"
          }
          env {
            name  = "TZ"
            value = "Asia/Seoul"
          }
        }
        image_pull_secrets {
          name = "ecr-secret"
        }
      }
    }
  }
}

resource "kubernetes_service" "kma_api" {
  metadata {
    name = "kma-api"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    selector = {
      app = "kma-api"
    }
    port {
      port        = 8000
      target_port = 8000
    }
  }
}

resource "kubernetes_deployment" "auth_chat_api" {
  metadata {
    name = "auth-chat-api"
    namespace = kubernetes_namespace.production.metadata[0].name
    labels = {
      app = "auth-chat-api"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "auth-chat-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "auth-chat-api"
        }
      }
      spec {
        container {
          name  = "auth-chat-api"
          image = var.auth_chat_api_image_url
          image_pull_policy = "Always"
        }
        image_pull_secrets {
          name = "ecr-secret"
        }
      }
    }
  }
}

resource "kubernetes_service" "auth_chat_api" {
  metadata {
    name = "auth-chat-api"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    selector = {
      app = "auth-chat-api"
    }
    port {
      port        = 8000
      target_port = 8000
    }
  }
}

resource "kubernetes_deployment" "web_v2_dashboard" {
  metadata {
    name = "web-v2-dashboard"
    namespace = kubernetes_namespace.production.metadata[0].name
    labels = {
      app = "web-v2-dashboard"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "web-v2-dashboard"
      }
    }
    template {
      metadata {
        labels = {
          app = "web-v2-dashboard"
        }
      }
      spec {
        container {
          name  = "web-v2-dashboard"
          image = var.web_dash_image_url
          image_pull_policy = "Always"
        }
        image_pull_secrets {
          name = "ecr-secret"
        }
      }
    }
  }
}

resource "kubernetes_service" "web_v2_dashboard" {
  metadata {
    name = "web-v2-dashboard"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    selector = {
      app = "web-v2-dashboard"
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}


# --------------------------------------------------------------------------------
# OpenShift Ingresses (Routes)
# --------------------------------------------------------------------------------

# Ingress for /main path with rewrite-target to /
resource "kubernetes_ingress_v1" "web_v2_dashboard_main" {
  metadata {
    name = "web-v2-dashboard-main"
    namespace = kubernetes_namespace.production.metadata[0].name
    annotations = {
      "haproxy.router.openshift.io/rewrite-target" = "/"
      "route.openshift.io/termination" = "edge"
    }
  }
  spec {
    rule {
      host = "www.cafekec.shop"
      http {
        path {
          path = "/main"
          path_type = "Prefix"
          backend {
            service {
              name = "web-v2-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    rule {
      host = "cafekec.shop"
      http {
        path {
          path = "/main"
          path_type = "Prefix"
          backend {
            service {
              name = "web-v2-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    rule {
      host = var.alb_dns_name
      http {
        path {
          path = "/main"
          path_type = "Prefix"
          backend {
            service {
              name = "web-v2-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for root and assets (NO rewrite-target to avoid breaking static files)
resource "kubernetes_ingress_v1" "web_v2_dashboard" {
  metadata {
    name = "web-v2-dashboard"
    namespace = kubernetes_namespace.production.metadata[0].name
    annotations = {
      "route.openshift.io/termination" = "edge"
    }
  }
  spec {
    rule {
      host = "www.cafekec.shop"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "web-v2-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    rule {
      host = "cafekec.shop"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "web-v2-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    rule {
      host = var.alb_dns_name
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "web-v2-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "kma_api_weather" {
  metadata {
    name = "kma-api-weather"
    namespace = kubernetes_namespace.production.metadata[0].name
    annotations = {
      "haproxy.router.openshift.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "route.openshift.io/termination"             = "edge"
    }
  }
  spec {
    rule {
      host = "www.cafekec.shop"
      http {
        path {
          path      = "/api/weather(/|$)(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "kma-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
    rule {
      host = "cafekec.shop"
      http {
        path {
          path      = "/api/weather(/|$)(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "kma-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
    rule {
      host = var.alb_dns_name
      http {
        path {
          path      = "/api/weather(/|$)(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "kma-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "kma_api_dust" {
  metadata {
    name = "kma-api-dust"
    namespace = kubernetes_namespace.production.metadata[0].name
    annotations = {
      "haproxy.router.openshift.io/rewrite-target" = "/dust"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/dust$2"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "route.openshift.io/termination"             = "edge"
    }
  }
  spec {
    rule {
      host = "www.cafekec.shop"
      http {
        path {
          path = "/api/dust"
          path_type = "Prefix"
          backend {
            service {
              name = "kma-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
    rule {
      host = "cafekec.shop"
      http {
        path {
          path = "/api/dust"
          path_type = "Prefix"
          backend {
            service {
              name = "kma-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
    rule {
      host = var.alb_dns_name
      http {
        path {
          path = "/api/dust"
          path_type = "Prefix"
          backend {
            service {
              name = "kma-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "ai_rag" {
  metadata {
    name = "ai-rag-route"
    namespace = kubernetes_namespace.production.metadata[0].name
    annotations = {
      "route.openshift.io/termination"             = "edge"
    }
  }
  spec {
    rule {
      host = "www.cafekec.shop"
      http {
        path {
          path      = "/api/ai"
          path_type = "Prefix"
          backend {
            service {
              name = "ai-rag"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
    rule {
      host = "cafekec.shop"
      http {
        path {
          path      = "/api/ai"
          path_type = "Prefix"
          backend {
            service {
              name = "ai-rag"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
    rule {
      host = var.alb_dns_name
      http {
        path {
          path      = "/api/ai"
          path_type = "Prefix"
          backend {
            service {
              name = "ai-rag"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_deployment" "ai_rag" {
  metadata {
    name = "ai-rag-app"
    namespace = kubernetes_namespace.production.metadata[0].name
    labels = {
      app = "ai-rag-app"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ai-rag-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "ai-rag-app"
        }
      }
      spec {
        container {
          name  = "ai-rag-app"
          image = var.ai_rag_image_url
          image_pull_policy = "Always"
          port {
            container_port = 3000
          }

          env {
            name  = "OLLAMA_HOST"
            value = "http://139.150.91.194:11434"
          }
          env {
            name  = "OLLAMA_HOST_PRIMARY"
            value = "http://139.150.91.194:11434"
          }
          env {
            name  = "OLLAMA_HOST_SECONDARY"
            value = "http://10.2.2.40:11434"
          }
          env {
            name  = "DEFAULT_MODEL"
            value = "llama3.1:70b"
          }
          env {
            name  = "KMA_API_URL"
            value = "http://kma-api:8000/weather/short"
          }
          env {
            name  = "ENERGY_API_URL"
            value = "http://energy-api:8000/kpx/now"
          }
        }
        image_pull_secrets {
          name = "ecr-secret"
        }
      }
    }
  }
}

resource "kubernetes_service" "ai_rag" {
  metadata {
    name = "ai-rag"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    selector = {
      app = "ai-rag-app"
    }
    port {
      port        = 3000
      target_port = 3000
    }
  }
}
"""

with open('./main.tf', 'w') as f:
    f.write(content_to_write)
