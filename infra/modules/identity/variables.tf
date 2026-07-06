variable "name_prefix" {
  description = "Prefix for naming and tagging"
  type        = string
  default     = "sentinelpay"
}

variable "github_org" {
  description = "GitHub organisation/owner for OIDC federation"
  type        = string
  default     = "asochi07"
}

variable "github_repo" {
  description = "GitHub repository for OIDC federation"
  type        = string
  default     = "Amdari-Project--02"
}

variable "payments_secret_arns" {
  description = "Secret ARNs the payments-api task role may read"
  type        = list(string)
  default     = []
}

variable "kyc_secret_arns" {
  description = "Secret ARNs the kyc-api task role may read"
  type        = list(string)
  default     = []
}

variable "payments_kms_key_arns" {
  description = "KMS key ARNs the payments-api task role may use"
  type        = list(string)
  default     = []
}

variable "kyc_kms_key_arns" {
  description = "KMS key ARNs the kyc-api task role may use"
  type        = list(string)
  default     = []
}

variable "app_bucket_arn" {
  description = "ARN of the application S3 bucket (kyc-api document access)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
