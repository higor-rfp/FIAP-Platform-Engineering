#!/bin/bash
# set -e: para no primeiro erro, para o SSM reportar falha de verdade (e o apply
# do Terraform abortar) em vez de seguir e marcar 'Success' enganosamente.
set -euo pipefail

echo "== bootstrap do GitLab Runner: preparando Python/pip/awscli para o Ansible =="

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y software-properties-common
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update -y

# Instala Python 3.8 (versao usada pelo runner) + pip + utilitarios do Ansible.
# Fazemos TODAS as operacoes de apt ANTES de mexer no update-alternatives: trocar
# o python3 default do sistema quebra o modulo apt_pkg (compilado p/ o python do
# SO) e faria o proprio apt parar de funcionar no meio do script.
apt-get install -y python3.8 python3.8-distutils python3-pip python3-apt awscli unzip

# Aponta apenas o comando 'python' (nao o python3 do sistema) para o 3.8, evitando
# quebrar ferramentas do SO que dependem do python3 original.
update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1

python --version
echo "== bootstrap concluido =="
