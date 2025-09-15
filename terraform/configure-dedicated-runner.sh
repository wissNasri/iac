#!/bin/bash
# Description: Script de configuration pour le runner GitHub dédié.
# Exécuté par user_data sur l'instance EC2.

# --- Variables de configuration ---
GH_OWNER="wissNasri"
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

# Récupérer le token d'enregistrement de manière sécurisée
echo "Récupération du token d'enregistrement depuis AWS Secrets Manager..."
GH_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$AWS_REGION" | jq -r '.SecretString')

if [ -z "$GH_TOKEN" ]; then
    echo "ERREUR: Impossible de récupérer le token depuis Secrets Manager. Vérifiez le nom du secret et les permissions IAM." >&2
    exit 1
fi
# --- Configuration du Runner GitHub ---

mkdir actions-runner; cd actions-runner
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-win-x64-2.328.0.zip -OutFile actions-runner-win-x64-2.328.0.zip
if((Get-FileHash -Path actions-runner-win-x64-2.328.0.zip -Algorithm SHA256).Hash.ToUpper() -ne 'a73ae192b8b2b782e1d90c08923030930b0b96ed394fe56413a073cc6f694877'.ToUpper()){ throw 'Computed checksum did not match' }
Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner-win-x64-2.328.0.zip", "$PWD")
./config.cmd --url https://github.com/wissNasri/iac --token BP6BWZZBMFBULUKZUNSSGG3IZCVPG
./run.cmd
runs-on: self-hosted
