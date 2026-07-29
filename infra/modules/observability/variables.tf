variable "name_prefix" {
  description = "Prefix for naming and tagging"
  type        = string
  default     = "sentinelpay"
}

variable "region" {
  description = "Primary region"
  type        = string
  default     = "af-south-1"
}

variable "cloudtrail_retention_years" {
  description = "Object Lock retention (years) for the CloudTrail bucket"
  type        = number
  default     = 1
}

variable "honeytoken_secret_name" {
  description = "Secrets Manager name for the decoy IAM key (reachable from app memory)"
  type        = string
  default     = "sentinelpay/app/legacy-backup-credentials"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
