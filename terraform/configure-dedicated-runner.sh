#!/bin/bash
# Description: Script de configuration pour le runner GitHub dédié.
# Exécuté par user_data sur l'instance EC2.

# --- Variables de configuration ---
GH_OWNER="WissNasri"
GH_REPO="terraformHelm"
RUNNER_LABELS="self-hosted,aws-private-runner"
RUNNER_DIR="/home/ubuntu/actions-runner"
AWS_REGION="us-east-1"
SECRET_ID="self_hosted_runner_pat" # Le nom de votre secret dans Secrets Manager

# --- Installation des dépendances ---
# Attendre que le réseau soit pleinement opérationnel
sleep 20
sudo apt-get update -y
# Outils nécessaires pour la pipeline terraformHelm et la configuration
sudo apt-get install -y curl jq unzip git software-properties-common
sudo snap install aws-cli --classic
sudo snap install kubectl --classic
sudo snap install helm --classic

# Installer Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs ) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# --- Configuration du Runner GitHub ---
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Récupérer le token d'enregistrement de manière sécurisée
echo "Récupération du token d'enregistrement depuis AWS Secrets Manager..."
GH_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$AWS_REGION" | jq -r '.SecretString')

if [ -z "$GH_TOKEN" ]; then
    echo "ERREUR: Impossible de récupérer le token depuis Secrets Manager. Vérifiez le nom du secret et les permissions IAM." >&2
    exit 1
fi

# Télécharger le logiciel du runner
echo "Téléchargement du logiciel du runner..."
LATEST_VERSION=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name' | sed 's/v//' )
RUNNER_TAR_BALL="actions-runner-linux-x64-${LATEST_VERSION}.tar.gz"
curl -o "$RUNNER_TAR_BALL" -L "https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/$RUNNER_TAR_BALL"
tar xzf "./$RUNNER_TAR_BALL"

# Configurer le runner (en mode non-interactif )
echo "Configuration du runner..."
# On exécute en tant qu'utilisateur 'ubuntu' pour éviter les problèmes de permissions
chown -R ubuntu:ubuntu "$RUNNER_DIR"
sudo -u ubuntu ./config.sh --url "https://github.com/${GH_OWNER}/${GH_REPO}" --token "$GH_TOKEN" --name "dedicated-runner-$(hostname )" --labels "$RUNNER_LABELS" --unattended --replace

# Installer le runner en tant que service pour qu'il redémarre automatiquement
echo "Installation et démarrage du service du runner..."
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "Configuration du runner dédiée terminée avec succès."
