# Fichier: iac/terraform/ec2-runner.tf
# Description: Provisionne l'instance EC2 dédiée pour le runner.

# 1. Groupe de sécurité pour le runner
resource "aws_security_group" "dedicated_runner_sg" {
  name        = "dedicated-runner-sg"
  description = "Security group for dedicated GitHub runner"
  vpc_id      = module.vpc.vpc_id

  # Aucune règle entrante. L'instance est inaccessible depuis l'extérieur.
  
  # Règle de sortie pour contacter GitHub, les dépôts de paquets, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-Dedicated-Runner"
  }
}

# 2. Instance EC2 dédiée
resource "aws_instance" "dedicated_github_runner" {
  # Réutilise l'AMI Ubuntu que vous avez définie pour votre bastion
  ami           = data.aws_ami.os_image.id 
  instance_type = "t3.medium"

  # --- Point clé de la sécurité : placement dans un subnet PRIVÉ ---
  subnet_id = module.vpc.private_subnets[0] 

  # Pas besoin d'IP publique, ce qui renforce la sécurité
  associate_public_ip_address = false

  # Attache le rôle IAM minimaliste créé dans iam-runner.tf
  iam_instance_profile = aws_iam_instance_profile.self_hosted_runner_profile.name
  
  # Attache le groupe de sécurité
  vpc_security_group_ids = [aws_security_group.dedicated_runner_sg.id]

  # Exécute le script de configuration au premier démarrage
  user_data = file("${path.module}/configure-dedicated-runner.sh")
  
  tags = {
    Name = "Dedicated-GitHub-Runner"
  }
}
