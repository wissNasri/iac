# Fichier : terraform/iam-policy.tf

resource "aws_iam_role_policy_attachment" "bastion_eks_access" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- AJOUT NÉCESSAIRE POUR L'ACCÈS SÉCURISÉ ---
# Attache la politique pour AWS Systems Manager Session Manager
resource "aws_iam_role_policy_attachment" "bastion_ssm_access" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
