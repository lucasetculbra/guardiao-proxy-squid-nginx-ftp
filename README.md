# Guardião Proxy: Controle de Acesso com Squid, Nginx e FTP

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Windows%2011-0078D6?logo=windows&logoColor=white)
![Squid](https://img.shields.io/badge/Squid-6.x-yellow)
![Nginx](https://img.shields.io/badge/Nginx-1.24-009639?logo=nginx&logoColor=white)
![vsftpd](https://img.shields.io/badge/vsftpd-3.0.5-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Atividade acadêmica de **Redes / Administração de Sistemas Linux**: o Squid age
como **guardião** de um portal Nginx (HTTP) e de um servidor vsftpd (FTP),
aplicando filtros de URL por palavra-chave, exceção por IP e ACLs específicas
para upload `.pdf` e download `.txt` no FTP.

## Sumário

- [Objetivo](#objetivo)
- [Arquitetura](#arquitetura)
- [Serviços](#serviços)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Como executar](#como-executar)
- [Tarefa A — Filtro de URL e exceção por IP](#tarefa-a--filtro-de-url-e-exceção-por-ip)
- [Tarefa B — ACLs de FTP](#tarefa-b--acls-de-ftp)
- [Configurar o Chrome para usar o Squid](#configurar-o-chrome-para-usar-o-squid)
- [URLs de teste](#urls-de-teste)
- [Logs](#logs)
- [Troubleshooting](#troubleshooting)
- [Reset](#reset)
- [Evidências](#evidências)
- [Licença](#licença)

## Objetivo

Montar uma infraestrutura local (**WSL2 Ubuntu 24.04**) onde todo acesso do
cliente passa pelo **Squid**, que decide o que liberar com base em:

1. **Lista de palavras proibidas** (`url_regex`).
2. **Lista de IPs liberados** (exceção que ignora o bloqueio).
3. **ACLs de FTP** combinando protocolo + método HTTP + sufixo do arquivo.

## Arquitetura

```
   +---------------------+
   |  Chrome (Windows)   |
   |  proxy: 127.0.0.1   |
   |  porta: 3128        |
   +----------+----------+
              |
              v
   +-------------------------------+
   |  Squid 6.x  (porta 3128)      |
   |  -------------------------    |
   |  1. http_access allow         |
   |       ip_liberado (exceção)   |
   |  2. http_access deny          |
   |       palavras_bloqueadas     |
   |  3. http_access deny          |
   |       ftp_proto + .pdf upload |
   |  4. http_access deny          |
   |       ftp_proto + .txt down   |
   +-----+-------------------+-----+
         |                   |
         v                   v
   +----------------+   +----------------+
   | Nginx (8080)   |   | vsftpd (21)    |
   | /var/www/portal|   | ftpuser/123456 |
   +----------------+   +----------------+
```

## Serviços

| Serviço | Porta | Função                                       |
|---------|-------|----------------------------------------------|
| Nginx   | 8080  | Portal HTML com páginas de teste            |
| Squid   | 3128  | Proxy HTTP/FTP com filtros e exceções        |
| vsftpd  | 21    | FTP local com usuário `ftpuser` / `123456`   |

## Estrutura do projeto

```
guardiao-proxy-squid-nginx-ftp/
├── README.md                # este arquivo
├── LICENSE                  # MIT
├── .gitignore
├── .gitattributes           # força LF em .sh/.conf/.txt/.md
├── scripts/
│   ├── install.sh           # apt install nginx squid vsftpd curl
│   ├── setup-nginx.sh       # /var/www/portal + vhost na 8080
│   ├── setup-ftp.sh         # ftpuser + arquivos de teste + vsftpd
│   ├── setup-squid.sh       # backup + aplica squid.conf + restart
│   ├── test-nginx.sh        # roda 5 testes via proxy e mostra OK/BLOQUEADO
│   ├── test-ftp.sh          # roda 4 testes (download/upload) via proxy
│   └── reset.sh             # restaura backups
├── configs/
│   ├── nginx-portal.conf    # vhost na porta 8080 com autoindex
│   ├── squid.conf           # ACLs + http_access ordenado
│   ├── palavras_bloqueadas.txt  # sexo / sexy / playboy / imagens
│   ├── ips_liberados.txt    # vazio - adicione um IP por linha
│   └── vsftpd-extra.conf    # local_enable, write_enable, pasv_*
└── evidencias/
    ├── comandos-testes.md   # roteiro para gerar evidências
    └── screenshots/         # capturas de tela das evidências
```

## Pré-requisitos

- Windows 10/11 com **WSL2** ativado.
- Distribuição **Ubuntu 24.04** no WSL.
- `git` (para clonar o repositório).
- Privilégios `sudo` no Ubuntu.

```bash
# clone no WSL
git clone https://github.com/lucasetculbra/guardiao-proxy-squid-nginx-ftp.git
cd guardiao-proxy-squid-nginx-ftp
```

> Você também pode acessar o projeto via `/mnt/c/Users/<seu_usuario>/...` se já
> estiver editando pelo VS Code do Windows. Nesse caso, scripts em `/mnt/c` não
> mantêm o bit `+x` de forma confiável: use **`sudo bash scripts/xxx.sh`** em
> vez de `./scripts/xxx.sh`.

## Como executar

```bash
chmod +x scripts/*.sh                 # opcional em /mnt/c
sudo bash scripts/install.sh          # apt install nginx squid vsftpd curl
sudo bash scripts/setup-nginx.sh      # portal em /var/www/portal, porta 8080
sudo bash scripts/setup-ftp.sh        # cria ftpuser/123456 + arquivos
sudo bash scripts/setup-squid.sh      # aplica /etc/squid/squid.conf
bash scripts/test-nginx.sh            # testes Tarefa A
bash scripts/test-ftp.sh              # testes Tarefa B
```

Saída esperada de `test-nginx.sh`:

```
[OK]         http://127.0.0.1:8080/             -> 200
[BLOQUEADO]  http://127.0.0.1:8080/sexo.html    -> 403
[BLOQUEADO]  http://127.0.0.1:8080/sexy.html    -> 403
[BLOQUEADO]  http://127.0.0.1:8080/playboy/     -> 403
[BLOQUEADO]  http://127.0.0.1:8080/imagens/     -> 403
```

Saída esperada de `test-ftp.sh`:

```
[OK download]        arquivo.dat     -> 200
[BLOQUEADO download] arquivo.txt     -> 403
[BLOQUEADO upload]   teste.pdf       -> 403
[OK upload]          teste.dat       -> 201
```

> **Curiosidade:** o Squid 6.x mapeia o código FTP `226 Transfer complete`
> para o HTTP `201 Created` em uploads bem-sucedidos via `curl -x -T`.

## Tarefa A — Filtro de URL e exceção por IP

### Bloqueio por palavra-chave

O arquivo [`configs/palavras_bloqueadas.txt`](configs/palavras_bloqueadas.txt)
lista as palavras proibidas (uma por linha):

```
sexo
sexy
playboy
imagens
```

No [`configs/squid.conf`](configs/squid.conf):

```conf
acl palavras_bloqueadas url_regex -i "/etc/squid/palavras_bloqueadas.txt"
...
http_access deny palavras_bloqueadas
```

O modificador `-i` torna a regex **case-insensitive** (`SEXY` também é bloqueado).

### Exceção por IP

[`configs/ips_liberados.txt`](configs/ips_liberados.txt) é uma lista de IPs
que **ignoram** o bloqueio:

```conf
acl ip_liberado src "/etc/squid/ips_liberados.txt"
...
http_access allow ip_liberado       # esta linha vem ANTES dos deny
http_access deny  palavras_bloqueadas
```

A ordem importa: a regra `allow` precede a `deny`, então qualquer IP listado
passa por tudo.

**Como liberar seu próprio IP:**

```bash
sudo tail -f /var/log/squid/access.log     # descubra o IP que aparece nas linhas
echo "SEU_IP_AQUI" | sudo tee -a /etc/squid/ips_liberados.txt
sudo systemctl reload squid
```

## Tarefa B — ACLs de FTP

```conf
acl ftp_proto      proto FTP
acl metodo_upload  method PUT POST
acl metodo_download method GET
acl pdf_upload     urlpath_regex -i \.pdf$
acl txt_download   urlpath_regex -i \.txt$

http_access deny ftp_proto metodo_upload  pdf_upload
http_access deny ftp_proto metodo_download txt_download
```

Cada `http_access deny` combina **3 ACLs** com **AND**:
o pedido só é bloqueado se for FTP **e** o método **e** o sufixo casarem.

### Teste manual via curl

```bash
PROXY=http://127.0.0.1:3128
FTP=ftp://ftpuser:123456@127.0.0.1

# Permitido
curl -x $PROXY $FTP/arquivo.dat -o /tmp/out.dat

# Bloqueado (download .txt)
curl -x $PROXY $FTP/arquivo.txt -o /tmp/out.txt -w "%{http_code}\n"

# Bloqueado (upload .pdf)
echo "x" > /tmp/teste.pdf
curl -x $PROXY -T /tmp/teste.pdf $FTP/teste.pdf -w "%{http_code}\n"

# Permitido
echo "x" > /tmp/teste.dat
curl -x $PROXY -T /tmp/teste.dat $FTP/teste.dat -w "%{http_code}\n"
```

> **Importante:** o Squid não é um proxy FTP nativo. A ACL `urlpath_regex` só
> tem efeito quando a requisição FTP **passa pelo Squid via HTTP**, como faz o
> `curl -x http://proxy:3128 ftp://...`. Consulte
> [Troubleshooting → FileZilla](#filezilla-não-respeita-as-regras-do-squid).

## Configurar o Chrome para usar o Squid

1. Windows → **Configurações** → **Sistema** → **Abrir as configurações de proxy**.
2. **Configuração manual de proxy** → ativar.
3. Endereço: `127.0.0.1` • Porta: `3128`.
4. Marcar "**Usar o servidor proxy também para todos os protocolos**".
5. Salvar.

Alternativas:

- Extensão **SwitchyOmega** no Chrome (perfil específico de proxy).
- Iniciar o Chrome com `chrome.exe --proxy-server=127.0.0.1:3128`.

## URLs de teste

Descubra o IP do WSL pelo Ubuntu:

```bash
hostname -I
```

Com o proxy configurado no Chrome:

| URL                                          | Esperado            |
|----------------------------------------------|---------------------|
| `http://IP_DO_WSL:8080/`                     | Portal carrega (200)|
| `http://IP_DO_WSL:8080/sexo.html`            | Squid: Access Denied|
| `http://IP_DO_WSL:8080/sexy.html`            | Squid: Access Denied|
| `http://IP_DO_WSL:8080/playboy/`             | Squid: Access Denied|
| `http://IP_DO_WSL:8080/imagens/`             | Squid: Access Denied|

## Logs

```bash
sudo tail -f /var/log/squid/access.log     # Squid (TCP_DENIED/403 = bloqueio)
sudo tail -f /var/log/nginx/access.log     # Nginx (acessos recebidos)
sudo tail -f /var/log/vsftpd.log           # vsftpd (FTP operations)
```

Formato típico do log do Squid quando bloqueia:

```
1715451234.567   0 127.0.0.1 TCP_DENIED/403 4221 GET http://127.0.0.1:8080/sexy.html - HIER_NONE/- text/html
```

## Troubleshooting

### Chrome no Windows não conecta no proxy do WSL2

O WSL2 normalmente já espelha o `localhost` do Windows para o Linux. Quando
falha, abra o **PowerShell como administrador** e crie um portproxy:

```powershell
$wslIp = (wsl hostname -I).Trim().Split(" ")[0]
netsh interface portproxy add v4tov4 listenport=3128 listenaddress=0.0.0.0 connectport=3128 connectaddress=$wslIp
```

Para listar / remover:

```powershell
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenport=3128 listenaddress=0.0.0.0
```

### Squid mostra "WARNING: empty ACL: ip_liberado"

Esperado. O arquivo `ips_liberados.txt` começa vazio (só comentários). Adicione
um IP por linha e `sudo systemctl reload squid`. O warning some.

### `chmod +x` não persiste em `/mnt/c`

Pastas em `/mnt/c` usam DrvFs (filesystem do Windows) e não suportam bit Unix.
A saída de `ls -l` mostra `777` mas é cosmético. Sempre invoque os scripts
com `bash script.sh` em vez de `./script.sh`.

### Conflito de porta 80 ao instalar o Nginx

Se a saída do `install.sh` mostrar `port 80 is already in use`, isso é OK —
nosso vhost ouve na **8080**, não na 80. O `setup-nginx.sh` desativa o
`sites-enabled/default` e reinicia o serviço.

### FileZilla não respeita as regras do Squid

O FileZilla abre conexão TCP direta para `vsftpd:21` (e portas passivas
`40000-40100`), **sem passar pelo Squid**. As ACLs `urlpath_regex` deste
laboratório dependem do tráfego chegar pelo Squid como HTTP. Use FileZilla
apenas para validar que o vsftpd está respondendo; para testar as regras,
use `curl -x http://127.0.0.1:3128 ftp://...`.

### Onde o Squid me enxergou?

```bash
sudo tail -n 5 /var/log/squid/access.log
```

Primeiro IP após o timestamp = o que o Squid vê. Em testes locais costuma ser
`127.0.0.1`; via Chrome do Windows é o IP do `eth0` do WSL ou o do gateway
NAT (varia).

## Reset

```bash
sudo bash scripts/reset.sh
```

- Restaura `/etc/squid/squid.conf` e `/etc/vsftpd.conf` a partir dos `.bak`
  criados pelos scripts de setup.
- Remove o vhost `portal` do Nginx e reativa o `default`.
- **Não** desinstala pacotes nem remove `/var/www/portal` ou `ftpuser`.

Para limpeza completa:

```bash
sudo rm -rf /var/www/portal
sudo userdel -r ftpuser
sudo apt-get remove --purge nginx squid vsftpd
```

## Evidências

Roteiro completo em [`evidencias/comandos-testes.md`](evidencias/comandos-testes.md):
8 blocos numerados cobrindo serviços ativos, controle (Nginx direto), Tarefa A
(bloqueio + exceção por IP), Tarefa B (download/upload), logs e teste no Chrome.

Coloque as capturas de tela em [`evidencias/screenshots/`](evidencias/screenshots/),
nomeando como `01-servicos-ativos.png`, `02-tarefa-a-bloqueio.png`, etc., na
mesma ordem dos blocos do roteiro.

## Licença

[MIT](LICENSE) © 2026 lucasetculbra
