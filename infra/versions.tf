terraform {
  required_version = ">= 1.7"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100" # pin to v5 line for consistency across the project
    }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
