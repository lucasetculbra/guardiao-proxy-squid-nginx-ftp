#!/usr/bin/env bash
# setup-nginx.sh - Configura o Nginx do portal (porta 8080) e cria páginas de teste.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORTAL_DIR="/var/www/portal"
SITE_CONF_SRC="$PROJECT_DIR/configs/nginx-portal.conf"
SITE_AVAILABLE="/etc/nginx/sites-available/portal"
SITE_ENABLED="/etc/nginx/sites-enabled/portal"

echo "==============================================="
echo " [nginx] Criando estrutura do portal em $PORTAL_DIR"
echo "==============================================="
sudo mkdir -p "$PORTAL_DIR/playboy" "$PORTAL_DIR/imagens"

echo "[nginx] Gerando páginas de teste..."
sudo tee "$PORTAL_DIR/index.html" > /dev/null <<'HTML'
<!DOCTYPE html>
<html lang="pt-br"><head><meta charset="utf-8"><title>Portal Guardião</title></head>
<body style="font-family:sans-serif">
<h1>Portal do Guardião Proxy</h1>
<p>Bem-vindo. Esta página é liberada pelo Squid.</p>
<ul>
  <li><a href="/sexo.html">/sexo.html</a> (deve ser bloqueada)</li>
  <li><a href="/sexy.html">/sexy.html</a> (deve ser bloqueada)</li>
  <li><a href="/playboy/">/playboy/</a> (deve ser bloqueada)</li>
  <li><a href="/imagens/">/imagens/</a> (deve ser bloqueada)</li>
</ul>
</body></html>
HTML

sudo tee "$PORTAL_DIR/sexo.html" > /dev/null <<'HTML'
<!DOCTYPE html><html><body><h1>Página sexo.html</h1>
<p>Se você está vendo isto SEM passar pelo Squid, é esperado.
Pelo proxy, o Squid deve bloquear.</p></body></html>
HTML

sudo tee "$PORTAL_DIR/sexy.html" > /dev/null <<'HTML'
<!DOCTYPE html><html><body><h1>Página sexy.html</h1>
<p>Bloqueada via Squid url_regex.</p></body></html>
HTML

sudo tee "$PORTAL_DIR/playboy/index.html" > /dev/null <<'HTML'
<!DOCTYPE html><html><body><h1>Pasta /playboy/</h1>
<p>Bloqueada via Squid url_regex.</p></body></html>
HTML

sudo tee "$PORTAL_DIR/imagens/index.html" > /dev/null <<'HTML'
<!DOCTYPE html><html><body><h1>Pasta /imagens/</h1>
<p>Bloqueada via Squid url_regex.</p></body></html>
HTML

sudo chown -R www-data:www-data "$PORTAL_DIR"

echo "==============================================="
echo " [nginx] Instalando vhost do portal"
echo "==============================================="
sudo cp "$SITE_CONF_SRC" "$SITE_AVAILABLE"
sudo ln -sf "$SITE_AVAILABLE" "$SITE_ENABLED"

# Desativa o site default para evitar conflito de listen na porta 80
if [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    echo "[nginx] Removido sites-enabled/default"
fi

echo "==============================================="
echo " [nginx] Validando configuração (nginx -t)"
echo "==============================================="
sudo nginx -t

echo "==============================================="
echo " [nginx] Reiniciando serviço"
echo "==============================================="
sudo systemctl restart nginx
sudo systemctl --no-pager status nginx | head -n 10 || true

echo
echo "[nginx] OK. Teste direto: curl http://127.0.0.1:8080/"
