#!/usr/bin/env bash
# test-ftp.sh - Testa as ACLs de FTP do Squid (download .txt bloqueado, upload .pdf bloqueado).
set -uo pipefail

PROXY="http://127.0.0.1:3128"
FTP_USER="ftpuser"
FTP_PASS="123456"
FTP_HOST="127.0.0.1"

check_download() {
    local arquivo="$1"
    local esperado="$2"
    local code
    code=$(curl -s -o /tmp/ftp_${arquivo}.out -w "%{http_code}" \
        -x "$PROXY" "ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}/${arquivo}" || echo "000")
    if [ "$esperado" = "permitido" ]; then
        if [ "$code" = "200" ] || [ "$code" = "226" ]; then
            printf "[OK download]        %-15s -> %s\n" "$arquivo" "$code"
        else
            printf "[FALHA download]     %-15s -> %s (esperado permitido)\n" "$arquivo" "$code"
        fi
    else
        if [ "$code" = "403" ]; then
            printf "[BLOQUEADO download] %-15s -> %s\n" "$arquivo" "$code"
        else
            printf "[FALHA download]     %-15s -> %s (esperado 403)\n" "$arquivo" "$code"
        fi
    fi
}

check_upload() {
    local arquivo_local="$1"
    local nome_remoto="$2"
    local esperado="$3"
    local code
    code=$(curl -s -o /tmp/ftp_upload.out -w "%{http_code}" \
        -x "$PROXY" -T "$arquivo_local" \
        "ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}/${nome_remoto}" || echo "000")
    if [ "$esperado" = "permitido" ]; then
        # Squid mapeia 226 (FTP transfer complete) para HTTP 201 Created
        if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "226" ]; then
            printf "[OK upload]          %-15s -> %s\n" "$nome_remoto" "$code"
        else
            printf "[FALHA upload]       %-15s -> %s (esperado permitido)\n" "$nome_remoto" "$code"
        fi
    else
        if [ "$code" = "403" ]; then
            printf "[BLOQUEADO upload]   %-15s -> %s\n" "$nome_remoto" "$code"
        else
            printf "[FALHA upload]       %-15s -> %s (esperado 403)\n" "$nome_remoto" "$code"
        fi
    fi
}

echo "==============================================="
echo " Preparando arquivos locais para upload"
echo "==============================================="
echo "Conteudo PDF de teste - $(date)" > /tmp/teste.pdf
echo "Conteudo DAT de teste - $(date)" > /tmp/teste.dat
ls -la /tmp/teste.pdf /tmp/teste.dat

echo
echo "==============================================="
echo " Testes de DOWNLOAD via Squid (FTP)"
echo "==============================================="
check_download "arquivo.dat" permitido
check_download "arquivo.txt" bloqueado

echo
echo "==============================================="
echo " Testes de UPLOAD via Squid (FTP)"
echo "==============================================="
check_upload "/tmp/teste.pdf" "teste.pdf" bloqueado
check_upload "/tmp/teste.dat" "teste.dat" permitido

echo
echo "Para inspecionar:  sudo tail -n 30 /var/log/squid/access.log"
