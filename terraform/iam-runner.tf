# Fichier: terraform/iam-runner.tf (Version Sécurisée)

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

# 2. NOUVELLE POLITIQUE IAM SUR MESURE
#    Cette politique est définie dans le fichier JSON que nous venons de créer.
resource "aws_iam_policy" "github_runner_least_privilege_policy" {
  name        = "GitHubRunnerLeastPrivilegePolicy"
  description = "Politique de moindre privilège pour le runner GitHub EC2."
  policy      = file("${path.module}/iam-runner-policy.json")
}

# 3. ATTACHER LA NOUVELLE POLITIQUE RESTREINTE
#    Nous attachons la politique sur mesure au rôle du runner.
resource "aws_iam_role_policy_attachment" "runner_least_privilege_attachment" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = aws_iam_policy.github_runner_least_privilege_policy.arn
}

# 4. SUPPRESSION DE L'ANCIENNE POLITIQUE
#    La ligne attachant "AdministratorAccess" est supprimée.
#
# resource "aws_iam_role_policy_attachment" "runner_admin_access" {
#   role       = aws_iam_role.self_hosted_runner_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }
#
# NOTE : La politique pour lire le PAT et celle pour SSM sont maintenant intégrées
# dans le fichier JSON principal pour une gestion centralisée.

# 5. Profil d'instance (inchangé)
resource "aws_iam_instance_profile" "self_hosted_runner_profile" {
  name = "GitHubRunnerInstanceProfile"
  role = aws_iam_role.self_hosted_runner_role.name
}
