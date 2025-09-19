# Fichier: terraform/cleanup.tf
# DESCRIPTION: Gère le nettoyage des ressources Kubernetes (comme l'Ingress et l'ALB)
#              qui ne sont pas gérées par Terraform, AVANT la destruction de l'infra.
#              Ceci évite les erreurs de "DependencyViolation".

# On a besoin du provider "local" pour exécuter des commandes sur la machine
# qui lance Terraform (dans notre cas, le runner GitHub Actions).
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
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

    # Commande à exécuter par le runner GitHub Actions
    # Elle configure kubectl, supprime le namespace, et attend.
    command = <<-EOT
      echo "####################################################################"
      echo "### DÉBUT DU NETTOYAGE KUBERNETES AVANT DESTRUCTION DE L'INFRA ###"
      echo "####################################################################"

      echo "1. Configuration de kubectl pour le cluster ${{module.eks.cluster_name}}..."
      aws eks update-kubeconfig --name ${{module.eks.cluster_name}} --region ${{local.region}}

      echo "2. Suppression du namespace 'quiz' pour supprimer l'Ingress et déclencher la suppression de l'ALB..."
      # On utilise "--ignore-not-found" pour ne pas échouer si le namespace n'existe plus.
      kubectl delete namespace quiz --ignore-not-found=true

      echo "3. ATTENTE DE 3 MINUTES pour laisser le temps à l'ALB Ingress Controller et à AWS de supprimer le Load Balancer."
      echo "   Cette pause est cruciale pour éviter les erreurs de dépendance."
      sleep 180

      echo "####################################################################"
      echo "### FIN DU NETTOYAGE. TERRAFORM VA MAINTENANT DÉTRUIRE L'INFRA. ###"
      echo "####################################################################"
    EOT
    
    # Interpréteur à utiliser pour la commande
    interpreter = ["bash", "-c"]
  }
}
