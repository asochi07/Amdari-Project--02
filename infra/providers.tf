provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "SentinelPay"
      ManagedBy  = "terraform"
      Engagement = "VaultBridge-Capstone"
    }
  }

  # --- Plan-only / offline settings ---
  # These let `terraform plan` run without real credentials or live API calls,
  # which is appropriate while we are validating IaC without an AWS account.
  # Remove (or they become harmless) once a real account is configured.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
