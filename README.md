# Guardião Proxy: Controle de Acesso com Squid, Nginx e FTP

Atividade acadêmica de Redes / Administração de Sistemas Linux.

## Objetivo

Montar uma infraestrutura local (WSL2 Ubuntu 24.04) onde o **Squid** funciona como
"guardião" do acesso a um **portal Nginx** e a um **servidor FTP (vsftpd)**, aplicando
filtros de URL e ACLs por método/protocolo.

## Arquitetura

```
   +-----------------+
   | Chrome (Windows)|---(proxy: 127.0.0.1:3128)---+
   +-----------------+                              |
                                                    v
                                       +---------------------------+
                                       |  Squid (porta 3128)       |
                                       |  - bloqueia palavras      |
                                       |  - exceção por IP         |
                                       |  - ACL FTP: -upload .pdf  |
                                       |             -download .txt|
                                       +-----+----------------+----+
                                             |                |
                                             v                v
                                  +-------------------+  +---------------+
                                  | Nginx (porta 8080)|  | vsftpd (21)   |
                                  | /var/www/portal   |  | usuario ftpuser|
                                  +-------------------+  +---------------+
```

## Serviços

| Serviço | Porta | Função                                       |
|---------|-------|----------------------------------------------|
| Nginx   | 8080  | Serve o portal HTML com páginas de teste     |
| Squid   | 3128  | Proxy HTTP/FTP com filtros e exceções        |
| vsftpd  | 21    | Servidor FTP com usuário `ftpuser` / `123456`|

## Tarefa A — Filtro de Conteúdo (Nginx + Squid)

O Squid bloqueia URLs que contenham qualquer uma das palavras abaixo
(`url_regex -i` sobre a lista em `/etc/squid/palavras_bloqueadas.txt`):

- `sexo`
- `sexy`
- `playboy`
- `imagens`

Há também uma regra de **exceção por IP**:
todo IP listado em `/etc/squid/ips_liberados.txt` ignora o bloqueio (a ACL
`http_access allow ip_liberado` vem **antes** das regras de `deny`).

## Tarefa B — Controle de Arquivos (FTP + Squid)

ACLs adicionais combinam protocolo FTP com método HTTP:

- `http_access deny ftp_proto metodo_upload pdf_upload` → bloqueia upload de `.pdf`
- `http_access deny ftp_proto metodo_download txt_download` → bloqueia download de `.txt`

> **Importante:** o Squid **não é um proxy FTP puro**. As ACLs `urlpath_regex` só
> funcionam quando o cliente faz a requisição FTP **através do proxy HTTP**, por
> exemplo via `curl`:
>
> ```bash
> curl -x http://127.0.0.1:3128 ftp://ftpuser:123456@127.0.0.1/arquivo.txt
> ```
>
> O **FileZilla** abre conexões TCP nativas para a porta 21, **sem passar pelo
> Squid** dessa forma, então as regras `urlpath_regex` não se aplicam.
> Use FileZilla apenas para validar que o vsftpd está no ar.

## Estrutura do projeto

```
guardiao-proxy-squid-nginx-ftp/
├── README.md
├── scripts/
│   ├── install.sh
│   ├── setup-nginx.sh
│   ├── setup-ftp.sh
│   ├── setup-squid.sh
│   ├── test-nginx.sh
│   ├── test-ftp.sh
│   └── reset.sh
├── configs/
│   ├── nginx-portal.conf
│   ├── squid.conf
│   ├── palavras_bloqueadas.txt
│   ├── ips_liberados.txt
│   └── vsftpd-extra.conf
└── evidencias/
    └── comandos-testes.md
```

## Passo a passo de execução

Abra o **WSL2 Ubuntu** e vá para a pasta do projeto:

```bash
cd /mnt/c/Users/luuca/OneDrive/Desktop/guardiao-proxy-squid-nginx-ftp
chmod +x scripts/*.sh         # opcional - em /mnt/c o bit pode não persistir
sudo bash scripts/install.sh
sudo bash scripts/setup-nginx.sh
sudo bash scripts/setup-ftp.sh
sudo bash scripts/setup-squid.sh
```

Depois rode os testes:

```bash
bash scripts/test-nginx.sh
bash scripts/test-ftp.sh
```

## Configurar o Chrome (Windows) para usar o Squid

1. Configurações → Sistema → Abrir as configurações de proxy do computador.
2. **Configuração manual de proxy** → ativar.
3. Endereço: `127.0.0.1`  •  Porta: `3128`.
4. Marcar "Usar o servidor proxy também para todos os protocolos".
5. Salvar.

> Em alguns Windows o Chrome usa o proxy do sistema; em outros é melhor usar uma
> extensão tipo **SwitchyOmega** ou iniciar o Chrome com
> `chrome.exe --proxy-server=127.0.0.1:3128`.

### Se o Chrome não conseguir conectar ao Squid no WSL

Geralmente o WSL2 já espelha `localhost`. Se não funcionar, abra o **PowerShell
como administrador** e crie um portproxy:

```powershell
$wslIp = wsl hostname -I
$wslIp = $wslIp.Trim().Split(" ")[0]
netsh interface portproxy add v4tov4 listenport=3128 listenaddress=0.0.0.0 connectport=3128 connectaddress=$wslIp
```

Para listar / remover:

```powershell
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenport=3128 listenaddress=0.0.0.0
```

## URLs de teste no navegador

Descubra o IP do WSL:

```bash
hostname -I
```

Depois acesse pelo Chrome (com o proxy configurado):

- http://IP_DO_WSL:8080/                  → **permitido**
- http://IP_DO_WSL:8080/sexo.html         → **bloqueado**
- http://IP_DO_WSL:8080/sexy.html         → **bloqueado**
- http://IP_DO_WSL:8080/playboy/          → **bloqueado**
- http://IP_DO_WSL:8080/imagens/          → **bloqueado**

## Como descobrir o IP que o Squid está enxergando

```bash
sudo tail -f /var/log/squid/access.log
```

O primeiro campo após a data é o IP do cliente. Copie esse IP e cole em
`/etc/squid/ips_liberados.txt` (um por linha) para liberá-lo:

```bash
sudo nano /etc/squid/ips_liberados.txt
sudo systemctl reload squid
```

## Testes FTP via curl (passando pelo Squid)

```bash
# Download permitido (.dat)
curl -x http://127.0.0.1:3128 ftp://ftpuser:123456@127.0.0.1/arquivo.dat -o /tmp/saida.dat

# Download BLOQUEADO (.txt)  -> deve retornar 403 do Squid
curl -x http://127.0.0.1:3128 ftp://ftpuser:123456@127.0.0.1/arquivo.txt -o /tmp/saida.txt -w "%{http_code}\n"

# Upload BLOQUEADO (.pdf)
echo "x" > /tmp/teste.pdf
curl -x http://127.0.0.1:3128 -T /tmp/teste.pdf ftp://ftpuser:123456@127.0.0.1/teste.pdf -w "%{http_code}\n"

# Upload permitido (.dat)
echo "x" > /tmp/teste.dat
curl -x http://127.0.0.1:3128 -T /tmp/teste.dat ftp://ftpuser:123456@127.0.0.1/teste.dat -w "%{http_code}\n"
```

## Logs

```bash
sudo tail -f /var/log/squid/access.log     # eventos do Squid (TCP_DENIED = bloqueio)
sudo tail -f /var/log/nginx/access.log     # acessos ao Nginx
sudo tail -f /var/log/vsftpd.log           # operações FTP (se habilitado)
```

## Observação sobre FileZilla

O Squid **não** é um proxy FTP nativo. Ele entende `ftp://` somente quando o
pedido chega pelo proxy **HTTP** (como o `curl -x` faz). O FileZilla abre uma
conexão TCP direta para a porta 21 e/ou 40000-40100 do vsftpd, **sem chamar o
Squid**, então as ACLs `urlpath_regex` deste laboratório **não se aplicam** a
sessões do FileZilla. Use o FileZilla apenas para validar que o vsftpd está
operacional.

## Reset

```bash
sudo bash scripts/reset.sh
```

Restaura `squid.conf` e `vsftpd.conf` a partir dos `.bak` criados pelos scripts e
remove o vhost `portal` do Nginx. **Não desinstala** os pacotes.
