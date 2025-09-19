# Fichier: terraform/cleanup.tf (CORRIGÉ)
# DESCRIPTION: Gère le nettoyage des ressources Kubernetes avant la destruction de l'infra.

# On a besoin du provider "local" pour exécuter des commandes sur la machine
# qui lance Terraform (dans notre cas, le runner GitHub Actions).
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    # Vous avez probablement déjà le provider "aws" dans un autre fichier,
    # mais il est bon de le déclarer ici aussi pour la clarté.
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Cette ressource "null_resource" ne crée rien.
# Elle sert uniquement de support pour exécuter un script au moment de la destruction.
resource "null_resource" "kubernetes_cleanup_before_destroy" {

  # Le provisioner "local-exec" s'exécute lorsque la ressource est détruite.
  provisioner "local-exec" {
    # La magie est ici : "when = destroy"
    when = destroy

    # On passe les variables Terraform au script via des variables d'environnement.
    # C'est la manière correcte et sécurisée de le faire.
    environment = {
      CLUSTER_NAME = module.eks.cluster_name
      AWS_REGION   = local.region
    }

    # Commande à exécuter par le runner GitHub Actions.
    # Le script utilise maintenant les variables d'environnement ($CLUSTER_NAME, $AWS_REGION).
    command = <<-EOT
      echo "####################################################################"
      echo "### DÉBUT DU NETTOYAGE KUBERNETES AVANT DESTRUCTION DE L'INFRA ###"
      echo "####################################################################"

      echo "1. Configuration de kubectl pour le cluster $CLUSTER_NAME..."
      aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

      echo "2. Suppression du namespace 'quiz' pour supprimer l'Ingress et déclencher la suppression de l'ALB..."
      kubectl delete namespace quiz --ignore-not-found=true

      echo "3. ATTENTE DE 3 MINUTES pour laisser le temps à l'ALB Ingress Controller et à AWS de supprimer le Load Balancer."
      echo "   Cette pause est cruciale pour éviter les erreurs de dépendance."
      sleep 180

      echo "####################################################################"
      echo "### FIN DU NETTOYAGE. TERRAFORM VA MAINTENANT DÉTRUIRE L'INFRA. ###"
      echo "####################################################################"
    EOT
    
    interpreter = ["bash", "-c"]
  }
}
