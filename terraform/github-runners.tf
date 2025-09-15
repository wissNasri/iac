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
    key_base64     = null  # Required if using GitHub App instead of PAT
    id             = null  # Required if using GitHub App instead of PAT
    webhook_secret = null  # Required if using GitHub App instead of PAT
  }

  # Alternative: Use PAT token directly (uncomment if not using GitHub App)
  # github_token = data.aws_secretsmanager_secret_version.github_pat.secret_string

  # Runner configuration
  instance_types = ["t3.medium"]  # Note: Now a list of strings :cite[9]
  
  # Network configuration
  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  # Security groups - use vpc_security_group_ids instead of security_group_ids :cite[10]
  vpc_security_group_ids = [aws_security_group.self_hosted_runner_sg.id]

  # Optional: Additional labels for the runners
  runner_extra_labels = "self-hosted,aws-private-runner"

  # Tags for all resources
  tags = {
    Name = "GitHub-Self-Hosted-Runner"
  }
}
