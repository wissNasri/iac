# Fichier: iac/terraform/github-runners.tf
# Description: Provisionne des runners GitHub auto-hébergés dans les sous-réseaux privés.

# 1. Récupérer le token GitHub depuis AWS Secrets Manager
data "aws_secretsmanager_secret_version" "github_pat" {
  # Le nom que vous avez donné au secret dans la console AWS
  secret_id = "self_hosted_runner_pat" 
}

# 2. Créer un groupe de sécurité pour les runners
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

# 3. Utiliser le module Terraform pour créer les runners
module "github_runners" {
  source  = "philips-labs/github-runner/aws"
  version = "6.1.0"

  github_owner = "wissNasri"
  github_token = data.aws_secretsmanager_secret_version.github_pat.secret_string

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  instance_type = "t3.medium"
  iam_role_name = "GitHubRunnerInstanceRole"
  
  security_group_ids = [aws_security_group.self_hosted_runner_sg.id]

  runner_labels = ["self-hosted", "aws-private-runner"]
  
  tags = {
    Name = "GitHub-Self-Hosted-Runner"
  }
}
