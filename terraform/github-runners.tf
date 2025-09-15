# ===================================================================
# 1. RÉCUPÉRER LE TOKEN GITHUB DEPUIS AWS SECRETS MANAGER
# ===================================================================
data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "self_hosted_runner_pat"
}

# ===================================================================
# 2. CRÉER UN GROUPE DE SÉCURITÉ POUR LES RUNNERS
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
# 3. MODULE TERRAFORM POUR CRÉER LES RUNNERS (VERSION CORRIGÉE)
# ===================================================================
module "github_runner" {
  source  = "github-aws-runners/github-runner/aws"
  version = "6.7.0"

  aws_region = local.region

  # Authentication - using PAT token from Secrets Manager
  github_app = {
    key_base64     = null
    id             = null  
    webhook_secret = null
  }

  # Alternative: Use PAT token directly
  github_token = data.aws_secretsmanager_secret_version.github_pat.secret_string

  # Runner configuration - corrected parameter names
  instance_types = ["t3.medium"]  # Note the plural 's' :cite[1]
  
  # Network configuration
  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  # Security configuration - using correct parameter name
  security_group_ids = [aws_security_group.self_hosted_runner_sg.id]  # Correct parameter name :cite[4]

  # Optional: Additional labels for the runners
  runner_extra_labels = "self-hosted,aws-private-runner"

  tags = {
    Name = "GitHub-Self-Hosted-Runner"
  }
}
