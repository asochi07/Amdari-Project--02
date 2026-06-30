variable "region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "af-south-1"
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "sentinelpay"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones (two, per architecture constraints)"
  type        = list(string)
  default     = ["af-south-1a", "af-south-1b"]
}
