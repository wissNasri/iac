# Fichier: iac/terraform/provider.tf (ou terraform.tf)

terraform {
  # Votre backend S3 existant
  backend "s3" {
    bucket         = "terraform-s3-backend-tws-hackathon111"
    key            = "backend-locking"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # On fixe une version 5.x stable et récente.
      version = "~> 5.40.0" 
    }
  }
}

# Votre configuration de provider existante
provider "aws" {
  region = local.region
}
