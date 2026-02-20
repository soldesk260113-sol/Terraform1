############################################################
# 기본 설정
############################################################
variable "name" {
  type        = string
  description = "WAF WebACL 이름 (예: dev-edge-webacl)"
}

variable "scope" {
  type        = string
  description = "WAF scope (REGIONAL for ALB / CLOUDFRONT for CF)"
  default     = "REGIONAL"
}

variable "default_action" {
  type        = string
  description = "기본 동작 (allow 또는 block)"
  default     = "allow"
}

############################################################
# 모니터링 설정
############################################################
variable "enable_cloudwatch_metrics" {
  type        = bool
  description = "CloudWatch 메트릭 활성화 여부"
  default     = true
}

variable "metric_name" {
  type        = string
  description = "CloudWatch metric 이름 prefix"
  default     = "waf"
}

############################################################
# AWS Managed Rule 설정
############################################################
variable "enable_managed_common" {
  type        = bool
  description = "AWSManagedRulesCommonRuleSet 사용 여부"
  default     = true
}

variable "enable_managed_known_bad_inputs" {
  type        = bool
  description = "AWSManagedRulesKnownBadInputsRuleSet 사용 여부"
  default     = true
}

variable "enable_managed_sqli" {
  type        = bool
  description = "AWSManagedRulesSQLiRuleSet 사용 여부"
  default     = true
}

variable "enable_managed_linux" {
  type        = bool
  description = "AWSManagedRulesLinuxRuleSet 사용 여부"
  default     = true
}

############################################################
# Rate Limit (IP 기반 요청 제한)
############################################################
variable "enable_rate_limit" {
  type        = bool
  description = "IP 기반 Rate Limit 사용 여부"
  default     = true
}

variable "rate_limit" {
  type        = number
  description = "5분 기준 IP당 요청 제한 수"
  default     = 1000
}

