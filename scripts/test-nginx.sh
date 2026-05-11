#!/usr/bin/env bash
# test-nginx.sh - Testa o filtro de URLs do Squid contra o portal Nginx.
set -uo pipefail

PROXY="http://127.0.0.1:3128"
BASE="http://127.0.0.1:8080"

check() {
    local url="$1"
    local esperado="$2"   # "permitido" | "bloqueado"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -x "$PROXY" "$url" || echo "000")

    if [ "$esperado" = "permitido" ]; then
        if [ "$code" = "200" ]; then
            printf "[OK]         %-40s -> %s (esperado permitido)\n" "$url" "$code"
        else
            printf "[FALHOU]     %-40s -> %s (esperado 200)\n" "$url" "$code"
        fi
    else
        if [ "$code" = "403" ] || [ "$code" = "407" ]; then
            printf "[BLOQUEADO]  %-40s -> %s (esperado bloqueado)\n" "$url" "$code"
        else
            printf "[FALHOU]     %-40s -> %s (esperado 403)\n" "$url" "$code"
        fi
    fi
}

echo "==============================================="
echo " Testes Nginx via Squid (proxy: $PROXY)"
echo "==============================================="
check "$BASE/"                 permitido
check "$BASE/sexo.html"        bloqueado
check "$BASE/sexy.html"        bloqueado
check "$BASE/playboy/"         bloqueado
check "$BASE/imagens/"         bloqueado

echo
echo "Para inspecionar:  sudo tail -n 20 /var/log/squid/access.log"
