#!/bin/bash
# Description: Script de configuration OPTIMISÉ pour le runner GitHub dédié.

# --- Variables de configuration ---
GH_OWNER="wissNasri"
GH_REPO="terraformHelm"
RUNNER_LABELS="self-hosted,aws-private-runner"
RUNNER_DIR="/home/ubuntu/actions-runner"
AWS_REGION="us-east-1"
SECRET_ID="self_hosted_runner_pat"

# --- Installation des dépendances (Méthode plus robuste) ---
# Attendre que le réseau soit pleinement opérationnel
sleep 20
sudo apt-get update -y
sudo apt-get install -y curl jq unzip git software-properties-common

# Installer AWS CLI v2 (méthode officielle, sans snap)
echo "Installation de AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Installer kubectl (méthode officielle )
echo "Installation de kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt )/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Installer Helm (méthode officielle)
echo "Installation de Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Installer Terraform (votre méthode est bonne et reste inchangée )
echo "Installation de Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs ) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# --- Configuration du Runner GitHub ---
# (Cette partie reste la même, mais elle devrait maintenant être atteinte)
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

echo "Récupération du token d'enregistrement depuis AWS Secrets Manager..."
GH_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$AWS_REGION" | jq -r '.SecretString')

if [ -z "$GH_TOKEN" ]; then
    echo "ERREUR: Impossible de récupérer le token depuis Secrets Manager." >&2
    exit 1
fi

echo "Téléchargement du logiciel du runner..."
LATEST_VERSION=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name' | sed 's/v//' )
RUNNER_TAR_BALL="actions-runner-linux-x64-${LATEST_VERSION}.tar.gz"
curl -o "$RUNNER_TAR_BALL" -L "https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/$RUNNER_TAR_BALL"
tar xzf "./$RUNNER_TAR_BALL"

chown -R ubuntu:ubuntu "$RUNNER_DIR"

echo "Configuration du runner..."
sudo -u ubuntu ./config.sh --url "https://github.com/${GH_OWNER}/${GH_REPO}" --token "$GH_TOKEN" --name "dedicated-runner-$(hostname )" --labels "$RUNNER_LABELS" --unattended --replace

echo "Installation et démarrage du service du runner..."
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "Configuration du runner dédiée terminée avec succès."
