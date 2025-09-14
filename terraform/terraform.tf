terraform {
  backend "s3" {
    bucket = "terraform-s3-backend-tws-hackathon111"
    key    = "backend-locking"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}
