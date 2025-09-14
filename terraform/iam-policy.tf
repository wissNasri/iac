resource "aws_iam_role_policy_attachment" "bastion_eks_access" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
