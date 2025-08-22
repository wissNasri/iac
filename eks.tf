module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = local.name
  cluster_version                 = "1.31"
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  cluster_security_group_additional_rules = {
    allow_bastion_https = {
      cidr_blocks = [aws_security_group.bastion_sg.id]  # limiter au bastion SG
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      type        = "ingress"
      description = "Allow HTTPS from Bastion"
    }
  }

  cluster_addons = {
    coredns   = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets     # Workers dans private subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    ng1 = {
      desired_size  = 1
      max_size      = 3
      min_size      = 1
      instance_types = ["t3.large"]

      remote_access = {
        ec2_ssh_key               = aws_key_pair.bastion_key.key_name
        source_security_group_ids = [aws_security_group.bastion_sg.id]
      }

      disk_size = 35
    }
  }

  access_entries = {
    bastion_role_access = {
      principal_arn = aws_iam_role.bastion_role.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = local.tags
}
