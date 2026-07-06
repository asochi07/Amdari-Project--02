variable "name_prefix" {
  description = "Prefix for naming and tagging"
  type        = string
  default     = "sentinelpay"
}

variable "vpc_id" {
  description = "VPC the data resources live in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS and ElastiCache (>= 2 AZs)"
  type        = list(string)
}

variable "app_security_group_ids" {
  description = "Security groups of the application services permitted to reach the data stores (by reference, not CIDR)"
  type        = list(string)
  default     = []
}

variable "kms_admin_arns" {
  description = "IAM principals allowed to ADMINISTER the KMS keys (separate from users)"
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "sentinelpay"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "sentinelpay_admin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
