#!/bin/bash
# Mettre à jour les paquets et installer les dépendances de base + Git
sudo apt-get update -y
sudo apt-get install -y snapd gnupg software-properties-common curl git

# Install AWS CLI
sudo snap install aws-cli --classic

# Install Helm
sudo snap install helm --classic

# Install Kubectl
sudo snap install kubectl --classic
# Install Terraform (official method)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform
