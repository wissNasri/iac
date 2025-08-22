terraform {
  backend "s3" {
    bucket         = "terraform-s3-backend-tws-hackathon11"
    key            = "backend-locking"
    region         = "eu-north-1"       # Valeur fixe, local.region ne fonctionne pas ici
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
