# Fichier: terraform/iam-runner.tf

# 1. Rôle IAM pour l'instance du runner (inchangé)
resource "aws_iam_role" "self_hosted_runner_role" {
  name = "GitHubRunnerInstanceRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 2. Politique pour lire le PAT (inchangé)
resource "aws_iam_policy" "read_github_pat_for_runner" {
  name        = "ReadGitHubPATForRunner"
  description = "Permet au runner de lire le secret du PAT GitHub"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "secretsmanager:GetSecretValue",
      Effect   = "Allow",
      Resource = "*" 
    }]
  })
}

# 3. Attacher la politique de lecture du PAT (inchangé)
resource "aws_iam_role_policy_attachment" "runner_can_read_pat" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = aws_iam_policy.read_github_pat_for_runner.arn
}

# 4. Attacher la politique Administrateur (conservée comme demandé)
resource "aws_iam_role_policy_attachment" "runner_admin_access" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- AJOUT NÉCESSAIRE POUR L'ACCÈS SÉCURISÉ ---
# 5. Attacher la politique pour AWS Systems Manager Session Manager
resource "aws_iam_role_policy_attachment" "runner_ssm_access" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# --- FIN DE L'AJOUT ---

# 6. Profil d'instance (inchangé)
resource "aws_iam_instance_profile" "self_hosted_runner_profile" {
  name = "GitHubRunnerInstanceProfile"
  role = aws_iam_role.self_hosted_runner_role.name
  # Cette ligne garantit que le profil attend la création complète du rôle.
  depends_on = [
    aws_iam_role.self_hosted_runner_role
  ]
}
