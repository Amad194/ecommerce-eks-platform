###############################################################################
# Remote state backend (partial config).
# The bucket name is account-specific, so it is supplied at init time rather
# than committed here:
#
#   terraform init -backend-config="bucket=<state-bucket-from-bootstrap>"
#
# (The CI pipeline passes this from the TF_STATE_BUCKET secret; the Makefile
# passes it from $TF_STATE_BUCKET. The bucket + lock table are created by
# terraform/bootstrap.)
###############################################################################

terraform {
  backend "s3" {
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ecommerce-tflock"
    encrypt        = true
  }
}
