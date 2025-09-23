#!/bin/bash
# Script complet pour installer et configurer un runner GitHub sur EC2
# Ce script sera exécuté automatiquement par Terraform (user_data).

# -------------------------------
# Variables à adapter
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
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt )/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Installer Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Installer Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs ) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

echo "--- Dépendances installées ---"

# -------------------------------
# Étape 2 : Récupérer le PAT GitHub depuis AWS Secrets Manager
# -------------------------------
GITHUB_PAT=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" | jq -r '.SecretString')

if [ -z "$GITHUB_PAT" ]; then
    echo "ERREUR: Impossible de récupérer le PAT. Vérifiez le nom du secret et les permissions IAM."
    exit 1
fi
echo "--- PAT récupéré avec succès ---"

# -------------------------------
# Étape 3 : Générer le token d'enregistrement temporaire
# -------------------------------
REG_TOKEN=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/runners/registration-token" | jq -r '.token' )

if [ -z "$REG_TOKEN" ]; then
    echo "ERREUR: Impossible de générer le token d'enregistrement pour le runner."
    exit 1
fi
echo "--- Token d'enregistrement temporaire généré ---"

# -------------------------------
# Étape 4 : Télécharger et configurer le runner
# -------------------------------
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

LATEST_VERSION=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name' | sed 's/v//' )
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
# Étape 5 : Installer et démarrer le service
# -------------------------------
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "--- Installation complète : le runner devrait être en ligne sur GitHub ---"
