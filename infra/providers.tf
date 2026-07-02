provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "SentinelPay"
      ManagedBy  = "terraform"
      Engagement = "VaultBridge-Capstone"
    }
  }
}
