#!/bin/bash
# set -e: o script PARA no primeiro erro. Sem isso, o SSM marcaria o comando como
# 'Success' mesmo que um passo falhasse no meio — dando falsa certeza ao apply.
set -euo pipefail

echo "== provisionando servidor web da Vortex =="

# Amazon Linux 2023 usa dnf e entrega nginx direto nos repositorios padrao
# (o antigo amazon-linux-extras nao existe mais nessa versao).
sudo dnf install -y nginx

# Garante que o nginx suba agora e tambem apos reboot.
sudo systemctl enable --now nginx

echo "nginx: $(systemctl is-active nginx)"
echo "== provisionamento concluido =="
