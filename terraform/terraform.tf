

terraform {
  # Votre backend S3 existant
  backend "s3" {
    bucket         = "terraform-s3-backend-tws-hackathon111"
    key            = "backend-locking"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  # --- AJOUTEZ CE BLOC CI-DESSOUS ---
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Force l'utilisation d'une version 5.x
    }
  }
}


