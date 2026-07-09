###############################################################################
# Remote state backend.
# The bucket/table below are created by terraform/bootstrap. If you changed the
# project name or use a different account, update these values (the bootstrap
# output prints the exact names).
#
# NOTE: <ACCOUNT_ID> must be replaced with your AWS account ID because S3 bucket
# names are globally unique. Run `terraform -chdir=terraform/bootstrap output`
# to get the exact bucket name.
###############################################################################

terraform {
  backend "s3" {
    bucket         = "ecommerce-tfstate-<ACCOUNT_ID>"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ecommerce-tflock"
    encrypt        = true
  }
}
