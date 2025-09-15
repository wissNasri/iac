# Fichier: iac/terraform/github-runners.tf
# Description: Provisionne des runners GitHub auto-hébergés (version moderne du module)

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
# 3. MODULE TERRAFORM POUR CRÉER LES RUNNERS (CORRIGÉ POUR LA v6.1.0)
# ===================================================================
module "github_runners" {
  # --- CORRECTION 1 : Le nom du module a changé ---
  source  = "terraform-aws-modules/github-runner/aws"
  version = "6.1.0" # On utilise la version que vous vouliez

  # --- CORRECTION 2 : La structure des arguments a complètement changé ---
  
  # Le module a besoin de connaître la région
  aws_region = local.region # Réutilise la variable de votre provider.tf

  # La méthode d'authentification a changé. On utilise ce bloc.
  github_auth = {
    # Le module est assez intelligent pour utiliser le token s'il est fourni
    token = data.aws_secretsmanager_secret_version.github_pat.secret_string
    owner = "WissNasri"
  }

  # La configuration des runners se fait maintenant dans ce bloc
  runners = {
    # Nommez votre groupe de runners
    private_runners_group = {
      # Les étiquettes sont définies ici
      labels = ["self-hosted", "aws-private-runner"]
      
      # Le type d'instance est défini ici
      instance_type = "t3.medium"
      
      # Le module gère la création du rôle IAM.
      # On attache notre groupe de sécurité supplémentaire.
      vpc_security_group_ids = [aws_security_group.self_hosted_runner_sg.id]
    }
  }

  # La configuration réseau reste la même
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Les tags restent les mêmes
  tags = {
    Name = "GitHub-Self-Hosted-Runner"
  }
}
