# Fichier: iac/terraform/iam-runner.tf (Solution Complète et Sécurisée)

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

# 2. Politique pour lire le PAT GitHub depuis Secrets Manager (inchangé)
resource "aws_iam_policy" "read_github_pat_for_runner" {
  name        = "ReadGitHubPATForRunner"
  description = "Permet au runner de lire le secret du PAT GitHub"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "secretsmanager:GetSecretValue",
      Effect   = "Allow",
      Resource = "arn:aws:secretsmanager:us-east-1:228578233417:secret:self_hosted_runner_pat-*" # Restreint à l'ARN du secret
    }]
  })
}

# 3. NOUVEAU : Politique "Permissions Boundary" pour la sécurité
# Cette politique définit les permissions maximales que les rôles créés par le runner peuvent avoir.
resource "aws_iam_policy" "runner_permissions_boundary" {
  name        = "RunnerPermissionsBoundary"
  description = "Limite les permissions des rôles créés par le runner GitHub."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Permissions pour l'ALB Controller
      {
        Effect   = "Allow",
        Action   = [
          "iam:CreateServiceLinkedRole",
          "ec2:Describe*",
          "elasticloadbalancing:*"
        ],
        Resource = "*"
      },
      # Permissions pour ExternalDNS
      {
        Effect   = "Allow",
        Action   = [
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      # Permissions pour EBS CSI Driver
      {
        Effect   = "Allow",
        Action   = "ec2:CreateTags",
        Resource = "arn:aws:ec2:*:*:volume/*"
      }
    ]
  })
}

# 4. NOUVEAU : Création de la politique principale sur mesure à partir du fichier JSON
resource "aws_iam_policy" "self_hosted_runner_main_policy" {
  name        = "GitHubRunnerMainPolicy"
  description = "Permissions minimales pour que le runner déploie les add-ons EKS"
  policy      = file("${path.module}/iam-runner-policy.json")
}

# 5. ATTACHEMENTS DES POLITIQUES AU RÔLE DU RUNNER

# Attachement de la politique principale sur mesure
resource "aws_iam_role_policy_attachment" "runner_main_access" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = aws_iam_policy.self_hosted_runner_main_policy.arn
}

# Attachement de la politique pour lire le PAT
resource "aws_iam_role_policy_attachment" "runner_can_read_pat" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = aws_iam_policy.read_github_pat_for_runner.arn
}

# Attachement de la politique pour l'accès de maintenance via SSM
resource "aws_iam_role_policy_attachment" "runner_ssm_access" {
  role       = aws_iam_role.self_hosted_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 6. Profil d'instance pour l'EC2 (inchangé)
resource "aws_iam_instance_profile" "self_hosted_runner_profile" {
  name = "GitHubRunnerInstanceProfile"
  role = aws_iam_role.self_hosted_runner_role.name
}
