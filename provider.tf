terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
  required_version = ">=1.5.0"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
# Explicit Provider for ACM Certificates (CloudFront Requirement)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  profile = var.aws_profile
}
