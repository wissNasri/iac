# Fichier: iac/terraform/ec2-runner.tf
# Description: Provisionne l'instance EC2 dédiée pour le runner avec accès SSH (Option 1)

# 1. Groupe de sécurité pour le runner
resource "aws_security_group" "dedicated_runner_sg" {
  name        = "dedicated-runner-sg"
  description = "Security group for dedicated GitHub runner"
  vpc_id      = module.vpc.vpc_id

  # Autoriser SSH uniquement depuis ton IP publique
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ remplace par ton IP publique
  }

  # Sortie vers internet (GitHub, apt, etc.)
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
  ami           = data.aws_ami.os_image.id 
  instance_type = "t3.micro" # ⚠️ Free Tier. Change si tu veux plus puissant

  # Placement dans un subnet PUBLIC
  subnet_id = module.vpc.public_subnets[0]

  # Attribution d’une IP publique
  associate_public_ip_address = true

  # Attache le rôle IAM minimaliste
  iam_instance_profile = aws_iam_instance_profile.self_hosted_runner_profile.name
  
  # Attache le groupe de sécurité
  vpc_security_group_ids = [aws_security_group.dedicated_runner_sg.id]

  # Script de configuration au premier démarrage
  user_data = file("${path.module}/configure-dedicated-runner.sh")
  
  tags = {
    Name = "Dedicated-GitHub-Runner"
  }
  depends_on = [module.vpc]

}
