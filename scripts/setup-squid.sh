#!/usr/bin/env bash
# setup-squid.sh - Aplica a configuração do Squid (proxy guardião).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SQUID_CONF="/etc/squid/squid.conf"
SRC_CONF="$PROJECT_DIR/configs/squid.conf"
SRC_PALAVRAS="$PROJECT_DIR/configs/palavras_bloqueadas.txt"
SRC_IPS="$PROJECT_DIR/configs/ips_liberados.txt"

echo "==============================================="
echo " [squid] Backup idempotente de $SQUID_CONF"
echo "==============================================="
if [ ! -f "${SQUID_CONF}.bak" ]; then
    sudo cp "$SQUID_CONF" "${SQUID_CONF}.bak"
    echo "[squid] Backup criado em ${SQUID_CONF}.bak"
else
    echo "[squid] Backup já existe - mantido."
fi

echo "==============================================="
echo " [squid] Copiando arquivos do projeto para /etc/squid"
echo "==============================================="
sudo cp "$SRC_CONF"     "$SQUID_CONF"
sudo cp "$SRC_PALAVRAS" /etc/squid/palavras_bloqueadas.txt
sudo cp "$SRC_IPS"      /etc/squid/ips_liberados.txt

# Garante leitura para o usuário do Squid (proxy)
sudo chown root:proxy /etc/squid/palavras_bloqueadas.txt /etc/squid/ips_liberados.txt 2>/dev/null || true
sudo chmod 0640       /etc/squid/palavras_bloqueadas.txt /etc/squid/ips_liberados.txt

echo "==============================================="
echo " [squid] Validando configuração (squid -k parse)"
echo "==============================================="
sudo squid -k parse

echo "==============================================="
echo " [squid] Reiniciando serviço"
echo "==============================================="
sudo systemctl restart squid
sleep 1
sudo systemctl --no-pager status squid | head -n 10 || true

echo
echo "[squid] OK. Proxy escutando em 3128."
echo "        Logs em: /var/log/squid/access.log"
