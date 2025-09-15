# Fichier: iac/terraform/iam-runner.tf
# Description: Crée le rôle IAM et le profil d'instance pour le runner EC2 dédié.

# 1. Rôle IAM pour l'instance du runner
# Ce rôle ne sert qu'à donner une identité de base à l'EC2.
resource "aws_iam_role" "self_hosted_runner_role" {
  name = "GitHubRunnerInstanceRole"
  
  # Politique de confiance : autorise l'instance EC2 à "porter" ce rôle.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 2. Politique pour autoriser la lecture du secret PAT depuis Secrets Manager
resource "aws_iam_policy" "read_github_pat_for_runner" {
  name        = "ReadGitHubPATForRunner"
  description = "Permet à l'instance du runner de lire le secret du PAT GitHub"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "secretsmanager:GetSecretValue",
      Effect   = "Allow",
      # IMPORTANT: Remplacez par l'ARN exact de votre secret pour une sécurité maximale.
      # Vous pouvez trouver l'ARN en cliquant sur votre secret dans la console AWS.
      Resource = "*" 

    }]
  })
}

# 3. Attacher la politique de lecture du secret au rôle du runner
resource "aws_iam_role_policy_attachment" "runner_can_read_pat" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = aws_iam_policy.read_github_pat_for_runner.arn
}

# 4. Créer un "profil d'instance", qui est le conteneur pour attacher un rôle à une EC2
resource "aws_iam_instance_profile" "self_hosted_runner_profile" {
  name = "GitHubRunnerInstanceProfile"
  role = aws_iam_role.self_hosted_runner_role.name
}
