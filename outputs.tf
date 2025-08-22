output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_node_group_public_ips" {
  value = module.eks.eks_managed_node_groups["ng1"].instances_public_ips
}
