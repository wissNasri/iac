# Fichier : terraform/endpoints.tf
# Rôle : Crée des "tunnels" privés pour que les ressources dans le VPC
# puissent communiquer avec les services AWS sans passer par Internet.

# --- Endpoint pour AWS Secrets Manager ---
# Permet au runner de récupérer le PAT GitHub.
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
  tags                = { Name = "vpc-endpoint-secretsmanager" }
}

# --- Endpoint pour AWS EC2 ---
# Souvent requis par l'AWS CLI pour fonctionner correctement dans un VPC.
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
  tags                = { Name = "vpc-endpoint-ec2" }
}

# --- Endpoint pour AWS STS (Security Token Service) ---
# Indispensable pour que l'instance puisse assumer son rôle IAM.
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
  tags                = { Name = "vpc-endpoint-sts" }
}

# --- Groupe de sécurité pour les Endpoints ---
# Autorise le trafic HTTPS entrant depuis n'importe où dans votre VPC.
resource "aws_security_group" "vpc_endpoint_sg" {
  name   = "vpc-endpoint-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "SG-VPC-Endpoints" }
}

