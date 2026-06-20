#!/bin/bash
set -eux
sudo apt-get update -y
# jq e usado pelos labs que provisionam via SSM (envia o script e le o log/status
# do comando). O AWS CLI ja vem da feature aws-cli do devcontainer.
sudo apt-get install -y jq
npm i serverless@3.39.0 -g
mkdir -p ~/.aws/
cp /workspaces/FIAP-Platform-Engineering/.devcontainer/config ~/.aws/config

# Confirma as ferramentas que os labs de Terraform/SSM dependem.
aws --version
jq --version
