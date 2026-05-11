#!/usr/bin/env bash
# setup-ftp.sh - Cria usuário FTP, arquivos de teste e ajusta o vsftpd.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FTP_USER="ftpuser"
FTP_PASS="123456"
EXTRA_CONF="$PROJECT_DIR/configs/vsftpd-extra.conf"
VSFTPD_CONF="/etc/vsftpd.conf"

echo "==============================================="
echo " [ftp] Garantindo usuário $FTP_USER"
echo "==============================================="
if id "$FTP_USER" >/dev/null 2>&1; then
    echo "[ftp] Usuário $FTP_USER já existe - pulando criação."
else
    sudo useradd -m -s /bin/bash "$FTP_USER"
    echo "[ftp] Usuário $FTP_USER criado."
fi
echo "$FTP_USER:$FTP_PASS" | sudo chpasswd
echo "[ftp] Senha definida (123456)."

FTP_HOME="$(getent passwd "$FTP_USER" | cut -d: -f6)"
echo "[ftp] HOME do usuário: $FTP_HOME"

echo "==============================================="
echo " [ftp] Criando arquivos de teste em $FTP_HOME"
echo "==============================================="
sudo tee "$FTP_HOME/arquivo.txt" > /dev/null <<'TXT'
Este é o arquivo arquivo.txt para teste de DOWNLOAD bloqueado pelo Squid.
Se você conseguir baixar via Squid, a regra txt_download falhou.
TXT

sudo tee "$FTP_HOME/arquivo.dat" > /dev/null <<'DAT'
Conteúdo binário fictício para teste de DOWNLOAD permitido via Squid.
DAT

sudo chown -R "$FTP_USER":"$FTP_USER" "$FTP_HOME/arquivo.txt" "$FTP_HOME/arquivo.dat"

echo "==============================================="
echo " [ftp] Backup de $VSFTPD_CONF (idempotente)"
echo "==============================================="
if [ ! -f "${VSFTPD_CONF}.bak" ]; then
    sudo cp "$VSFTPD_CONF" "${VSFTPD_CONF}.bak"
    echo "[ftp] Backup criado em ${VSFTPD_CONF}.bak"
else
    echo "[ftp] Backup já existe - mantido."
fi

echo "==============================================="
echo " [ftp] Aplicando vsftpd-extra.conf (idempotente)"
echo "==============================================="
while IFS= read -r line; do
    # ignora comentários e linhas em branco
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    key="${line%%=*}"
    if sudo grep -qE "^[[:space:]]*${key}=" "$VSFTPD_CONF"; then
        # já existe alguma definição da chave - substitui pela nossa
        sudo sed -i -E "s|^[[:space:]]*${key}=.*|${line}|" "$VSFTPD_CONF"
        echo "[ftp]  ajustado: $line"
    else
        echo "$line" | sudo tee -a "$VSFTPD_CONF" > /dev/null
        echo "[ftp]  adicionado: $line"
    fi
done < "$EXTRA_CONF"

echo "==============================================="
echo " [ftp] Reiniciando vsftpd"
echo "==============================================="
sudo systemctl restart vsftpd
sudo systemctl --no-pager status vsftpd | head -n 10 || true

echo
echo "[ftp] OK."
echo "      Teste local:   curl ftp://${FTP_USER}:${FTP_PASS}@127.0.0.1/arquivo.dat"
echo "      Teste via Squid: curl -x http://127.0.0.1:3128 ftp://${FTP_USER}:${FTP_PASS}@127.0.0.1/arquivo.dat"
