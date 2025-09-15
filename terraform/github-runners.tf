# Fichier: iac/terraform/github-runners.tf
# Description: Provisionne des runners GitHub auto-hébergés (version moderne et corrigée)

# ===================================================================
# 1. RÉCUPÉRER LE TOKEN GITHUB DEPUIS AWS SECRETS MANAGER
# Cette partie est correcte et reste inchangée.
# ===================================================================
data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "self_hosted_runner_pat"
}

# ===================================================================
# 2. CRÉER UN GROUPE DE SÉCURITÉ POUR LES RUNNERS
# Cette partie est correcte et reste inchangée.
# ===================================================================
resource "aws_security_group" "self_hosted_runner_sg" {
  name        = "self-hosted-runner-sg"
  description = "Security group for self-hosted GitHub runners"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG Self-Hosted Runner"
  }
}

# ===================================================================
# 3. MODULE TERRAFORM POUR CRÉER LES RUNNERS (VERSION FINALE ET CORRIGÉE)
# Ce bloc contient le nom de module et la structure d'arguments corrects pour la v6.1.0.
# ===================================================================
module "github_runner" {
  # Le nom correct du module sur le registre Terraform
  source  = "terraform-aws-modules/runner/aws"   
  version = "6.7.0"

  # Argument requis par le module pour connaître la région
  aws_region = local.region

  # Nouvelle méthode d'authentification requise par le module
  github_auth = {
    token = data.aws_secretsmanager_secret_version.github_pat.secret_string
    owner = "WissNasri"
  }

  # Nouvelle structure pour définir les runners
  runners = {
    private_runners_group = {
      labels                 = ["self-hosted", "aws-private-runner"]
      instance_type          = "t3.medium"
      vpc_security_group_ids = [aws_security_group.self_hosted_runner_sg.id]
    }
  }

  # Configuration réseau
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Tags pour les ressources créées
  tags = {
    Name = "GitHub-Self-Hosted-Runner"
  }
}
