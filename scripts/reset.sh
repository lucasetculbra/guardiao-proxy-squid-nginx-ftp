#!/usr/bin/env bash
# reset.sh - Reverte a configuração do laboratório (não desinstala pacotes).
set -uo pipefail

echo "==============================================="
echo " [reset] Restaurando Squid"
echo "==============================================="
if [ -f /etc/squid/squid.conf.bak ]; then
    sudo cp /etc/squid/squid.conf.bak /etc/squid/squid.conf
    echo "[reset] squid.conf restaurado a partir do .bak"
else
    echo "[reset] /etc/squid/squid.conf.bak não encontrado - pulando."
fi
sudo rm -f /etc/squid/palavras_bloqueadas.txt /etc/squid/ips_liberados.txt
sudo systemctl restart squid || true

echo "==============================================="
echo " [reset] Removendo vhost do Nginx (portal)"
echo "==============================================="
sudo rm -f /etc/nginx/sites-enabled/portal
sudo rm -f /etc/nginx/sites-available/portal
if [ ! -L /etc/nginx/sites-enabled/default ] && [ -f /etc/nginx/sites-available/default ]; then
    sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    echo "[reset] sites-enabled/default reativado"
fi
sudo nginx -t && sudo systemctl restart nginx || true

echo "==============================================="
echo " [reset] Restaurando vsftpd"
echo "==============================================="
if [ -f /etc/vsftpd.conf.bak ]; then
    sudo cp /etc/vsftpd.conf.bak /etc/vsftpd.conf
    echo "[reset] vsftpd.conf restaurado a partir do .bak"
else
    echo "[reset] /etc/vsftpd.conf.bak não encontrado - pulando."
fi
sudo systemctl restart vsftpd || true

echo
echo "[reset] OK. Arquivos /var/www/portal e usuário ftpuser foram MANTIDOS."
echo "        Para remoção completa, faça manualmente:"
echo "          sudo rm -rf /var/www/portal"
echo "          sudo userdel -r ftpuser"
