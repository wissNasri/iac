#############################################
# Fichier : iac/terraform/github-runners.tf
# But    : Provisionner des runners GitHub auto-hébergés
# Module : terraform module "github-aws-runners/github-runner/aws" v6.1.0
#############################################

# -------------------------
# Exemple minimal de provider
# (si vous avez déjà provider.tf, ignorez ce bloc)
# -------------------------
provider "aws" {
  region = var.aws_region
}

# -------------------------
# Exemple local (si vous aviez utilisé local.region)
# (si vous avez déjà un locals.tf, retirez ce bloc)
# -------------------------
locals {
  region = var.aws_region
}

# -------------------------
# Récupération du token GitHub depuis AWS Secrets Manager
# (secret_id doit exister et contenir soit le token brut,
#  soit un JSON contenant une clé "token")
# -------------------------
data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "self_hosted_runner_pat"
}

# -------------------------
# Si le secret est un JSON {"token":"ghp_..."} :
# Décommentez la ligne `token = ...jsondecode...` et commentez la ligne `token = data...secret_string`
# -------------------------
# Exemple d'extraction :
# token = jsondecode(data.aws_secretsmanager_secret_version.github_pat.secret_string)["token"]

# -------------------------
# Groupe de sécurité pour les runners
# -------------------------
resource "aws_security_group" "self_hosted_runner_sg" {
  name        = "self-hosted-runner-sg"
  description = "Security group for self-hosted GitHub runners"
  vpc_id      = module.vpc.vpc_id

  # Autoriser le trafic sortant HTTPS (GitHub API, actions runners, mises à jour)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optionnel : autoriser le trafic sortant DNS/HTTP si nécessaire
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG Self-Hosted Runner"
  }
}

# -------------------------
# Module GitHub Runners (version 6.1.0)
# Source officiel : terraform registry -> github-aws-runners/github-runner/aws
# -------------------------
module "github_runners" {
  source  = "github-aws-runners/github-runner/aws"
  version = "6.1.0"

  # Région AWS (reprend le local.region)
  aws_region = local.region

  # Auth GitHub - adaptez owner/org selon votre compte
  github_auth = {
    # Si votre secret contient le token brut :
    token = data.aws_secretsmanager_secret_version.github_pat.secret_string

    # Si votre secret est un JSON {"token":"<value>"} utilisez à la place :
    # token = jsondecode(data.aws_secretsmanager_secret_version.github_pat.secret_string)["token"]

    owner = "WissNasri" # remplacez par votre user / org GitHub
  }

  # Définition des groupes de runners (structure v6.x)
  runners = {
    private_runners_group = {
      labels                 = ["self-hosted", "aws-private-runner"]
      instance_type          = "t3.medium"
      desired_capacity       = 1      # ajustez selon vos besoins
      min_size               = 0
      max_size               = 2
      # Ajout du groupe de sécurité personnalisé
      vpc_security_group_ids = [aws_security_group.self_hosted_runner_sg.id]

      # Optionnel : clés SSH, AMI, user_data, tags, etc. Exemples commentés ci-dessous.
      # key_name = "my-ssh-key"
      # ami_id   = "ami-0123456789abcdef0"
      # user_data = file("${path.module}/user_data.sh")
    }
  }

  # Réseau (VPC / subnets provenant de votre module VPC)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Tags appliqués aux ressources
  tags = {
    Name = "GitHub-Self-Hosted-Runner"
    Owner = "WissNasri"
  }

  # Optionnel : si vous utilisez des IAM roles/customizations déjà existants
  # iam_role_arn = aws_iam_role.my_custom_role.arn
}

# -------------------------
# Notes / recommandations
# -------------------------
# - Si votre secret dans Secrets Manager contient un JSON, utilisez jsondecode(...) pour récupérer la clé nécessaire.
# - Vérifiez que le token GH a les permissions pour enregistrer des self-hosted runners (repo/org: admin:runner).
# - Ajustez instance_type, auto-scaling (desired/min/max) selon la charge attendue.
# - Si vos runners doivent accéder à Internet et que vous êtes dans des subnets privées, assurez-vous que ces subnets ont NAT/egress.
# - Sur CI (GitHub Actions runner ou pipeline Terraform), vérifier la possibilité d'accès à registry.terraform.io pour télécharger le module.
#
# -------------------------
# FIN du fichier
# -------------------------
