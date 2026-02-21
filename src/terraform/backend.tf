terraform {
  backend "s3" {
    bucket  = "massive-stocks-api-tfstate"
    key     = "massive-stocks/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}