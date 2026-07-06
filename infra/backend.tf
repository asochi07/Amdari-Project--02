###############################################################################
# Remote state backend (S3 + DynamoDB lock).

###############################################################################

terraform {
  backend "s3" {
    bucket         = "sentinelpay-tfstate-asochi07"
    key            = "network/terraform.tfstate"
    region         = "af-south-1"
    dynamodb_table = "sentinelpay-tflock"
    encrypt        = true
  }
}
