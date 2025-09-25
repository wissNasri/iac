resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-instance-profile-"
  role = aws_iam_role.bastion_eks_role.name
  depends_on = [
    aws_iam_role.bastion_eks_role
  ]

  
}
