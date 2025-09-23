#!/bin/bash
# Script complet pour installer et configurer un runner GitHub sur EC2
# Ce script sera exécuté automatiquement par Terraform (user_data).

# -------------------------------
# Variables
# -------------------------------
GH_OWNER="wissNasri"
GH_REPO="terraformHelm"
RUNNER_LABELS="self-hosted,aws-private-runner"
RUNNER_DIR="/home/ubuntu/actions-runner"
AWS_REGION="us-east-1"
SECRET_ID="self_hosted_runner_pat"

# -------------------------------
# Étape 1 : Installer les dépendances
# -------------------------------
sudo apt-get update -y
sudo apt-get install -y curl jq unzip git software-properties-common

# Installer AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Installer kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt  )/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Installer Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ===================================================================
# MODIFICATION : Installation manuelle de Terraform pour contrôler la version
# ===================================================================
echo "--- Installation de Terraform v1.8.5 ---"
TERRAFORM_VERSION="1.8.5"
curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo install terraform /usr/local/bin/
rm terraform terraform_${TERRAFORM_VERSION}_linux_amd64.zip
echo "--- Terraform v${TERRAFORM_VERSION} installé avec succès ---"
terraform --version # Affiche la version pour confirmation
# ===================================================================

echo "--- Dépendances installées ---"

# -------------------------------
# Étape 2 : Récupérer le PAT GitHub
# -------------------------------
GITHUB_PAT=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" | jq -r '.SecretString' )

if [ -z "$GITHUB_PAT" ]; then
    echo "ERREUR: Impossible de récupérer le PAT."
    exit 1
fi
echo "--- PAT récupéré avec succès ---"

# -------------------------------
# Étape 3 : Générer le token d'enregistrement
# -------------------------------
REG_TOKEN=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/runners/registration-token" | jq -r '.token'  )

if [ -z "$REG_TOKEN" ]; then
    echo "ERREUR: Impossible de générer le token d'enregistrement."
    exit 1
fi
echo "--- Token d'enregistrement temporaire généré ---"

# -------------------------------
# Étape 4 : Configurer le runner
# -------------------------------
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

LATEST_VERSION=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name' | sed 's/v//'  )
RUNNER_TAR="actions-runner-linux-x64-${LATEST_VERSION}.tar.gz"
curl -O -L "https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/${RUNNER_TAR}"
tar xzf $RUNNER_TAR

chown -R ubuntu:ubuntu "$RUNNER_DIR"

sudo -u ubuntu ./config.sh \
  --url "https://github.com/${GH_OWNER}/${GH_REPO}" \
  --token "$REG_TOKEN" \
  --name "dedicated-runner-$(hostname )" \
  --labels "$RUNNER_LABELS" \
  --unattended --replace

# -------------------------------
# Étape 5 : Démarrer le service
# -------------------------------
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "--- Installation complète : le runner devrait être en ligne sur GitHub ---"
