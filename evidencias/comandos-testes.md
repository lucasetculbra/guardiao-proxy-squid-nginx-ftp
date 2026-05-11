# Evidências — Comandos de teste

Roteiro de comandos para gerar evidências (capturas/logs) da atividade
**Guardião Proxy: Squid + Nginx + FTP**.

> Execute cada bloco no WSL2 Ubuntu e capture o terminal (Print do VS Code /
> screenshot da janela). Os comandos `tail` mostram a linha exata que o Squid
> registrou no momento do teste.
>
> Salve as capturas em [`screenshots/`](screenshots/) com a convenção
> `0X-nome-curto.png`, onde `X` é o número do bloco abaixo. Exemplo:
> `01-servicos-ativos.png`, `03-tarefa-a-bloqueio.png`, `08-chrome-bloqueio.png`.

---

## 1. Verificar serviços ativos

```bash
sudo systemctl is-active nginx squid vsftpd
ss -tlnp | grep -E "(:8080|:3128|:21 )"
```

Resultado esperado: `active` para os três; `ss` deve mostrar os 3 sockets.

---

## 2. Testar Nginx **sem** o Squid (controle)

```bash
curl -s -o /dev/null -w "direto -> %{http_code}\n" http://127.0.0.1:8080/
curl -s -o /dev/null -w "direto -> %{http_code}\n" http://127.0.0.1:8080/sexy.html
```

Esperado: ambos `200`. Acesso direto não é filtrado.

---

## 3. Tarefa A — Bloqueio de palavras via Squid

```bash
PROXY=http://127.0.0.1:3128
BASE=http://127.0.0.1:8080

for u in / sexo.html sexy.html playboy/ imagens/; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -x $PROXY ${BASE}/${u})
    echo "${u}  ->  ${code}"
done
```

Esperado:
- `/`            → `200`
- `sexo.html`    → `403`
- `sexy.html`    → `403`
- `playboy/`     → `403`
- `imagens/`     → `403`

Conferir no log:

```bash
sudo tail -n 10 /var/log/squid/access.log
```

Procure `TCP_DENIED/403` na linha das URLs bloqueadas.

---

## 4. Tarefa A — Exceção por IP

Descubra o IP que o Squid está enxergando:

```bash
sudo tail -n 5 /var/log/squid/access.log
```

(O primeiro IP após a data é o seu.) Em testes via WSL local, geralmente é
`127.0.0.1`. Libere esse IP:

```bash
echo "127.0.0.1" | sudo tee -a /etc/squid/ips_liberados.txt
sudo systemctl reload squid
```

Repita o teste do passo 3 — agora todas as URLs devem retornar `200`,
**mesmo as proibidas**, pois a regra `http_access allow ip_liberado` vem antes
das de bloqueio.

Para voltar ao comportamento de bloqueio, remova a linha do arquivo e
`sudo systemctl reload squid`.

---

## 5. Tarefa B — Download via FTP através do Squid

```bash
PROXY=http://127.0.0.1:3128
FTP=ftp://ftpuser:123456@127.0.0.1

curl -s -o /tmp/out.dat -w "arquivo.dat -> %{http_code}\n" -x $PROXY $FTP/arquivo.dat
curl -s -o /tmp/out.txt -w "arquivo.txt -> %{http_code}\n" -x $PROXY $FTP/arquivo.txt
```

Esperado:
- `arquivo.dat` → `200`/`226` (download OK)
- `arquivo.txt` → `403` (bloqueado pela ACL `txt_download`)

---

## 6. Tarefa B — Upload via FTP através do Squid

```bash
echo "PDF de teste $(date)" > /tmp/teste.pdf
echo "DAT de teste $(date)" > /tmp/teste.dat

curl -s -o /tmp/u.out -w "upload .pdf -> %{http_code}\n" \
    -x $PROXY -T /tmp/teste.pdf $FTP/teste.pdf

curl -s -o /tmp/u.out -w "upload .dat -> %{http_code}\n" \
    -x $PROXY -T /tmp/teste.dat $FTP/teste.dat
```

Esperado:
- `upload .pdf` → `403` (bloqueado pela ACL `pdf_upload`)
- `upload .dat` → `200`/`226` (upload OK)

Confira no servidor FTP:

```bash
sudo ls -la /home/ftpuser/
```

Deve ter aparecido `teste.dat`, mas **não** `teste.pdf`.

---

## 7. Logs para evidência final

```bash
echo "===== SQUID ====="
sudo tail -n 30 /var/log/squid/access.log

echo "===== NGINX ====="
sudo tail -n 20 /var/log/nginx/portal-access.log 2>/dev/null \
    || sudo tail -n 20 /var/log/nginx/access.log

echo "===== VSFTPD ====="
sudo tail -n 30 /var/log/vsftpd.log 2>/dev/null \
    || sudo journalctl -u vsftpd --no-pager | tail -n 30
```

---

## 8. Teste via navegador (Chrome no Windows)

Com o proxy `127.0.0.1:3128` configurado:

| URL                                          | Resultado esperado                |
|----------------------------------------------|-----------------------------------|
| `http://IP_DO_WSL:8080/`                     | Página do portal carregando       |
| `http://IP_DO_WSL:8080/sexo.html`            | Tela do Squid: *ERROR / Access Denied* |
| `http://IP_DO_WSL:8080/sexy.html`            | Tela do Squid: *Access Denied*    |
| `http://IP_DO_WSL:8080/playboy/`             | Tela do Squid: *Access Denied*    |
| `http://IP_DO_WSL:8080/imagens/`             | Tela do Squid: *Access Denied*    |

> Capture a tela da página de erro do Squid e a entrada correspondente em
> `/var/log/squid/access.log` (linha com `TCP_DENIED/403`).
