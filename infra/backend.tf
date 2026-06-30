###############################################################################
# Remote state backend (S3 + DynamoDB lock).
#
# This is COMMENTED OUT deliberately. The backend resources are created by
# infra/bootstrap first (chicken-and-egg). Once bootstrap has been applied to
# a real account, uncomment this block and run `terraform init` to migrate
# state from local to S3.
#
# Until then, the root config uses local state, which is correct for the
# plan/validate-only phase.
###############################################################################

# terraform {
#   backend "s3" {
#     bucket         = "sentinelpay-tfstate-asochi07"
#     key            = "network/terraform.tfstate"
#     region         = "af-south-1"
#     dynamodb_table = "sentinelpay-tflock"
#     encrypt        = true
#   }
# }
