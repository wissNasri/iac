# Fichier: iac/terraform/provider.tf (ou terraform.tf)

terraform {
  # Votre backend S3 existant
  backend "s3" {
    bucket         = "terraform-s3-backend-tws-hackathon1111"
    key            = "backend-locking"
    region         = "us-east-1"

  }


}

