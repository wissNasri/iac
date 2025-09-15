# Fichier: iac/terraform/github-runners.tf
# Description: Version finale et correcte pour le module "github-aws-runners/github-runner/aws" v6.7.0

# ===================================================================
# 1. RÉCUPÉRER LE TOKEN GITHUB DEPUIS AWS SECRETS MANAGER (INCHANGÉ)
# ===================================================================
data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "self_hosted_runner_pat"
}

# ===================================================================
# 2. CRÉER UN GROUPE DE SÉCURITÉ POUR LES RUNNERS (INCHANGÉ)
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
# 3. MODULE TERRAFORM POUR CRÉER LES RUNNERS (CORRIGÉ SELON LES ERREURS)
# ===================================================================
module "github_runner" {
  # Votre source et version
  source  = "github-aws-runners/github-runner/aws"
  version = "6.7.0"

  # Argument requis par ce module
  aws_region = local.region

  # --- CORRECTION : Le module attend "github_app", pas "github_auth" ---
  github_app = {
    key_base64 = ""
    id         = ""
    token      = data.aws_secretsmanager_secret_version.github_pat.secret_string
    owner      = "WissNasri"
  }

  # --- CORRECTION : Le module attend "runner_groups", pas "runners" ---
  runners = {
    private_runners_group = {
      labels                 = ["self-hosted", "aws-private-runner"]
      instance_type          = "t3.micro" # J'ai gardé t3.micro comme vous l'avez mis
      vpc_security_group_ids = [aws_security_group.self_hosted_runner_sg.id]
    }
  }

  # Configuration réseau
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Tags
  tags = {
    Name = "GitHub-Self-Hosted-Runner"
  }
}
