resource "aws_security_group" "node_group_remote_access" {
  name   = "allow HTTP"
  vpc_id = module.vpc.vpc_id
  ingress {
    description = "port 22 allow"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = " allow all outgoing traffic "
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


locals {
  # ... (vos autres variables locales)

  # ===================================================================
  # LISTE MANUELLE, MAIS COMPLÈTE ET OFFICIELLE, DES ADRESSES IP DE GITHUB ACTIONS
  # Collez ici le résultat exact de la commande curl.
  # ===================================================================
  github_actions_ips = [
    "192.30.252.0/22",
    "185.199.108.0/22",
    "140.82.112.0/20",
    "143.55.64.0/20",
    "2a0a:a440::/29",
    "2605:d000:1::/48"
    # ASSUREZ-VOUS DE COPIER LA LISTE COMPLÈTE DE LA COMMANDE CURL
  ]

  admin_ips = [
    # "YOUR_HOME_IP/32", # N'oubliez pas d'ajouter votre IP si nécessaire
  ]
}

module "eks" {

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = local.name
  cluster_version                 = "1.31"
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = local.github_actions_ips

  //access entry for any specific user or role (jenkins controller instance)
  access_entries = {
    # One access entry with a policy associated
    example = {
      principal_arn = aws_iam_role.bastion_eks_role.arn

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    github_actions_access = {
      # L'ARN du rôle IAM que vos workflows utilisent pour se connecter à AWS
      principal_arn = "arn:aws:iam::228578233417:role/oicd" 
      policy_associations = {
        admin_policy = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }


  cluster_security_group_additional_rules = {
    access_for_bastion_jenkins_hosts = {
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all HTTPS traffic from jenkins and Bastion host"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      type        = "ingress"
    }
  }


  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group(s)

  eks_managed_node_group_defaults = {

    instance_types = ["t3.large"]

    attach_cluster_primary_security_group = true

  }



  eks_managed_node_groups = {

    tws-demo-ng = {
      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = ["c7i-flex.large"]
      capacity_type  = "SPOT"

      disk_size                  = 35
      use_custom_launch_template = false # Important to apply disk size!

    #  remote_access = {
     #   ec2_ssh_key               = resource.aws_key_pair.deployer.key_name
     #   source_security_group_ids = [aws_security_group.node_group_remote_access.id]
     # }

      tags = {
        Name        = "tws-demo-ng"
        Environment = "dev"
        ExtraTag    = "e-commerce-app"
      }
    }
  }

  tags = local.tags


}

data "aws_instances" "eks_nodes" {
  instance_tags = {
    "eks:cluster-name" = module.eks.cluster_name
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.eks]
}
