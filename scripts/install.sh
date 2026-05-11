#!/usr/bin/env bash
# install.sh - Instala pacotes necessários para a atividade Guardião Proxy.
set -euo pipefail

echo "==============================================="
echo " [install] Atualizando lista de pacotes (apt)  "
echo "==============================================="
sudo apt-get update -y

echo "==============================================="
echo " [install] Instalando nginx, squid, vsftpd, curl"
echo "==============================================="
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nginx \
    squid \
    vsftpd \
    curl

echo "==============================================="
echo " [install] Dando permissão de execução aos scripts"
echo "==============================================="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo
echo "[install] OK - pacotes instalados."
echo "          Próximo passo: sudo bash scripts/setup-nginx.sh"
