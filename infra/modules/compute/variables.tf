variable "name_prefix" {
  description = "Prefix for naming and tagging"
  type        = string
  default     = "sentinelpay"
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB (>= 2 AZs)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the ECS tasks (>= 2 AZs)"
  type        = list(string)
}

variable "payments_task_role_arn" {
  description = "ECS task role ARN for payments-api (from identity module)"
  type        = string
}

variable "kyc_task_role_arn" {
  description = "ECS task role ARN for kyc-api (from identity module)"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN (image pull, logs). If empty, one is created."
  type        = string
  default     = ""
}

variable "container_image" {
  description = "Container image for the tasks. Placeholder public image proves the wiring; real images arrive with the CI/CD pipeline."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "payments_container_port" {
  description = "Container port for payments-api"
  type        = number
  default     = 80 # nginx placeholder listens on 80; real payments-api is 8001
}

variable "kyc_container_port" {
  description = "Container port for kyc-api"
  type        = number
  default     = 80 # nginx placeholder listens on 80; real kyc-api is 8002
}

variable "desired_count" {
  description = "Number of tasks per service"
  type        = number
  default     = 1
}

variable "rate_limit_per_5min" {
  description = "WAF rate-limit threshold (requests per 5 minutes per IP) on the payments path"
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
