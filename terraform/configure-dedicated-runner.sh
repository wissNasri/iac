#!/bin/bash
# Description: Script de configuration FINAL, basé sur les instructions GitHub et automatisé.

# --- Variables de configuration ---
GH_OWNER="wissNasri"
GH_REPO="terraformHelm"
RUNNER_LABELS="self-hosted,aws-private-runner"
RUNNER_DIR="/home/ubuntu/actions-runner"
AWS_REGION="us-east-1"
SECRET_ID="self_hosted_runner_pat" # Le nom de votre secret PAT

# --- Installation des dépendances (Méthode fiable sans snap) ---
echo "--- Etape 1: Installation des dépendances ---"
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
echo "--- Dépendances installées avec succès ---"

# --- Configuration du Runner GitHub ---
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# --- Etape 2: Récupération du token d'enregistrement ---
# C'est l'étape qui remplace le token à usage unique que vous avez montré.
# On utilise le PAT (stocké dans Secrets Manager) pour demander un token d'enregistrement temporaire à l'API GitHub.
echo "--- Etape 2: Récupération du token d'enregistrement via l'API GitHub ---"
GITHUB_PAT=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$AWS_REGION" | jq -r '.SecretString')

if [ -z "$GITHUB_PAT" ]; then
    echo "ERREUR: Impossible de récupérer le PAT depuis Secrets Manager." >&2
    exit 1
fi

# On utilise le PAT pour obtenir un token d'enregistrement (valable 1 heure)
REG_TOKEN=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/runners/registration-token" | jq -r '.token' )

if [ -z "$REG_TOKEN" ]; then
    echo "ERREUR: Impossible d'obtenir un token d'enregistrement depuis l'API GitHub. Vérifiez que votre PAT est valide et a les bonnes permissions ('repo')." >&2
    exit 1
fi
echo "--- Token d'enregistrement obtenu avec succès ---"

# --- Etape 3: Téléchargement et configuration du runner ---
echo "--- Etape 3: Téléchargement et configuration du runner ---"
# On utilise la méthode de téléchargement que vous avez montrée, mais en la rendant dynamique
LATEST_VERSION=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name' | sed 's/v//' )
RUNNER_TAR_BALL="actions-runner-linux-x64-${LATEST_VERSION}.tar.gz"
curl -o "$RUNNER_TAR_BALL" -L "https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/$RUNNER_TAR_BALL"
tar xzf "./$RUNNER_TAR_BALL"

chown -R ubuntu:ubuntu "$RUNNER_DIR"

# On utilise le token d'enregistrement (REG_TOKEN ) que nous venons de générer
sudo -u ubuntu ./config.sh --url "https://github.com/${GH_OWNER}/${GH_REPO}" --token "$REG_TOKEN" --name "dedicated-runner-$(hostname )" --labels "$RUNNER_LABELS" --unattended --replace
echo "--- Configuration terminée ---"

# --- Etape 4: Installation en tant que service ---
# C'est l'étape qui remplace le "./run.sh" pour un fonctionnement permanent.
echo "--- Etape 4: Installation du service ---"
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "--- Script terminé. Le runner devrait être en ligne. ---"
