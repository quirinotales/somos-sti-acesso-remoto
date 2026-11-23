#!/usr/bin/env bash
# Somos STI Acesso Remoto - instala ou atualiza o servidor com painel
#
# Uso (como root, no servidor):
#     bash instalar-painel.sh <versao> [endereco]
#     bash instalar-painel.sh 2026.11.1 remoto.somossti.com.br
#
# O que faz, nesta ordem (para em qualquer erro, sem deixar o servidor pela metade):
#   1. Baixa a versão do GitHub da STI e confere o SHA-256
#   2. Monta a imagem Docker local
#   3. Faz cópia de segurança de /opt/sti-acesso-remoto/dados (chave incluída)
#   4. Troca os containers sti-hbbs e sti-hbbr pela versão nova, mantendo a MESMA chave
#   5. Na primeira instalação, troca a senha de fábrica do admin por uma aleatória
#   6. Publica o painel em HTTPS pelo Nginx que já existe (arquivo novo, sem tocar nos outros sites)
#
# O que NÃO faz: não apaga nada, não mexe em outros containers, não altera os sites
# existentes do Nginx e não reinicia o Nginx (só recarrega, depois de testar a configuração).

set -euo pipefail

VERSAO="${1:-}"
DESTINO="${STI_DESTINO:-/opt/sti-acesso-remoto}"
REPO="${STI_REPO:-quirinotales/somos-sti-acesso-remoto}"
ORIGEM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_CONF="${STI_NGINX_CONF:-/etc/nginx/conf.d/sti-acesso-remoto.conf}"
ACME_DIR="${STI_ACME_DIR:-/var/www/sti-acme}"
API="http://127.0.0.1:21114"
AGORA="$(date +%Y%m%d-%H%M%S)"

vermelho() { printf '\033[1;31m%s\033[0m\n' "$*"; }
verde()    { printf '\033[1;32m%s\033[0m\n' "$*"; }
amarelo()  { printf '\033[1;33m%s\033[0m\n' "$*"; }
titulo()   { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
falha()    { vermelho "$*"; exit 1; }
# Nunca parar em silêncio: qualquer erro não tratado diz em que linha foi.
trap 'vermelho "Erro inesperado na linha $LINENO (comando: $BASH_COMMAND). Envie esta saída para análise."' ERR

# ---------------------------------------------------------------- conferências iniciais
[ "$(id -u)" -eq 0 ] || falha "Rode como root."
echo "$VERSAO" | grep -Eq '^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$' || falha "Informe a versão, por exemplo: bash instalar-painel.sh 2026.11.1"
for cmd in docker curl sha256sum tar; do
  command -v "$cmd" >/dev/null 2>&1 || falha "Comando necessário não encontrado: $cmd"
done
docker compose version >/dev/null 2>&1 || falha "Este Docker não tem o 'docker compose'. Nada foi alterado."
for arq in Dockerfile docker-compose.yml oauth2.toml; do
  [ -f "$ORIGEM/$arq" ] || falha "Arquivo $arq não encontrado ao lado deste script ($ORIGEM)."
done

ENDERECO="${2:-}"
[ -z "$ENDERECO" ] && [ -f "$DESTINO/endereco.txt" ] && ENDERECO="$(tr -d ' \r\n' < "$DESTINO/endereco.txt")"
[ -n "$ENDERECO" ] || falha "Informe o endereço público, por exemplo: bash instalar-painel.sh $VERSAO remoto.somossti.com.br"

PRIMEIRA_VEZ=nao
[ -f "$DESTINO/dados/secret_key.txt" ] || PRIMEIRA_VEZ=sim

# Baixa uma URL para um arquivo. Alguns provedores falham ao resolver *.githubusercontent.com:
# se a tentativa normal falhar, repete resolvendo os nomes por DNS-over-HTTPS (Cloudflare),
# só para este comando, sem mexer no DNS do sistema.
baixar() { # $1 = URL, $2 = arquivo de destino
  curl -fL --retry 2 -sS -o "$2" "$1" 2>/dev/null && return 0
  echo "  (download direto falhou; tentando com DNS-over-HTTPS)"
  curl -fL --retry 2 -sS --doh-url https://1.1.1.1/dns-query -o "$2" "$1"
}

# ---------------------------------------------------------------- 1. download
titulo "1/6 Download da versão $VERSAO"
PACOTE="somos-sti-servidor-$VERSAO-linux-amd64"
BASE="https://github.com/$REPO/releases/download/sti-v$VERSAO"
VDIR="$DESTINO/versoes/$VERSAO"
mkdir -p "$VDIR"
if [ ! -x "$VDIR/$PACOTE/hbbs" ]; then
  baixar "$BASE/$PACOTE.tar.gz" "$VDIR/$PACOTE.tar.gz" \
    || falha "Não consegui baixar $BASE/$PACOTE.tar.gz (a versão já foi publicada no GitHub?). Nada foi alterado."
  baixar "$BASE/SHA256SUMS" "$VDIR/SHA256SUMS" || falha "Não consegui baixar o SHA256SUMS. Nada foi alterado."
  (cd "$VDIR" && sha256sum -c SHA256SUMS) || falha "O SHA-256 do pacote não confere. Nada foi alterado."
  tar -C "$VDIR" -xzf "$VDIR/$PACOTE.tar.gz"
fi
[ -x "$VDIR/$PACOTE/hbbs" ] && [ -x "$VDIR/$PACOTE/hbbr" ] || falha "Pacote incompleto em $VDIR."
verde "Pacote conferido: $(cut -c1-16 "$VDIR/SHA256SUMS")…"

# ---------------------------------------------------------------- 2. imagem
titulo "2/6 Imagem Docker local"
cp "$ORIGEM/Dockerfile" "$VDIR/$PACOTE/Dockerfile"
docker build -q -t "somos-sti-servidor:$VERSAO" "$VDIR/$PACOTE" >/dev/null
docker run --rm --network none "somos-sti-servidor:$VERSAO" hbbs --version \
  || falha "A imagem nova não executa. Nada foi alterado no servidor em produção."
verde "Imagem somos-sti-servidor:$VERSAO pronta."

# ---------------------------------------------------------------- 3. cópia de segurança
titulo "3/6 Cópia de segurança"
mkdir -p "$DESTINO/dados" "$DESTINO/backup"
BKP="$DESTINO/backup/dados-$AGORA"
cp -a "$DESTINO/dados" "$BKP"
chmod 700 "$DESTINO/backup"
verde "Cópia em $BKP"
if [ -f "$DESTINO/dados/id_ed25519.pub" ]; then
  CHAVE_ANTES="$(tr -d '\r\n' < "$DESTINO/dados/id_ed25519.pub")"
else
  CHAVE_ANTES=""
fi

# ---------------------------------------------------------------- 4. troca dos containers
titulo "4/6 Troca do servidor"
cd "$DESTINO"
if [ -f docker-compose.yml ] && ! grep -q 'somos-sti-servidor' docker-compose.yml; then
  # Servidor antigo (sem painel): para os dois containers e guarda o que era dele.
  docker compose stop hbbs hbbr 2>/dev/null || true
  mv docker-compose.yml "docker-compose.yml.antigo-$AGORA"
  mkdir -p "dados/servidor-antigo-$AGORA"
  for f in dados/db_v2.sqlite3 dados/db_v2.sqlite3-shm dados/db_v2.sqlite3-wal; do
    [ -e "$f" ] && mv "$f" "dados/servidor-antigo-$AGORA/"
  done
  echo "Servidor antigo parado; o banco dele foi movido para dados/servidor-antigo-$AGORA (não apagado)."
fi
cp "$ORIGEM/docker-compose.yml" "$DESTINO/docker-compose.yml"
[ -f "$DESTINO/dados/oauth2.toml" ] || cp "$ORIGEM/oauth2.toml" "$DESTINO/dados/oauth2.toml"
echo "$ENDERECO" > "$DESTINO/endereco.txt"

SO_LOGADO="N"
[ -f "$DESTINO/.env" ] && SO_LOGADO="$(grep -E '^STI_SO_LOGADO=' "$DESTINO/.env" | cut -d= -f2 || true)"
cat > "$DESTINO/.env" <<EOF
STI_VERSAO=$VERSAO
STI_ENDERECO=$ENDERECO
STI_SO_LOGADO=${SO_LOGADO:-N}
EOF

# O servidor roda sem root dentro do container (usuário 10001): ele precisa ser dono da pasta de dados.
chown -R 10001:10001 "$DESTINO/dados"
chmod 700 "$DESTINO/dados"
[ -f "$DESTINO/dados/id_ed25519" ] && chmod 600 "$DESTINO/dados/id_ed25519"

docker compose up -d --remove-orphans

echo "Aguardando o servidor responder..."
OK=nao
for _ in $(seq 1 40); do
  if curl -fsS -o /dev/null "$API/ui/" 2>/dev/null; then OK=sim; break; fi
  sleep 1
done
if [ "$OK" != sim ]; then
  docker logs --tail 30 sti-hbbs || true
  falha "O servidor novo não respondeu. Os dados originais estão em $BKP."
fi

CHAVE_DEPOIS="$(tr -d '\r\n' < "$DESTINO/dados/id_ed25519.pub")"
if [ -n "$CHAVE_ANTES" ] && [ "$CHAVE_ANTES" != "$CHAVE_DEPOIS" ]; then
  falha "A chave pública mudou! Pare e restaure $BKP antes de gerar qualquer instalador."
fi
verde "Servidor novo no ar, com a mesma chave."

# ---------------------------------------------------------------- 5. senha do admin
titulo "5/6 Senha do administrador"
SENHA_ARQ="$DESTINO/SENHA-INICIAL-ADMIN.txt"
if [ "$PRIMEIRA_VEZ" = sim ]; then
  TOKEN="$(curl -fsS -X POST "$API/api/login" -H 'Content-Type: application/json' \
      -d '{"username":"admin","password":"Hello,world!","id":"instalador","uuid":"instalador"}' 2>/dev/null \
      | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true)"
  if [ -n "$TOKEN" ]; then
    NOVA="$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | cut -c1-20)"
    CODIGO="$(curl -sS -o /dev/null -w '%{http_code}' -X PUT "$API/api/user/password" \
        -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
        -d "{\"current_password\":\"Hello,world!\",\"new_password\":\"$NOVA\"}")"
    if [ "$CODIGO" = 200 ]; then
      umask 077
      printf 'Usuario: admin\nSenha:   %s\n\nTroque esta senha no primeiro login (menu do usuario > Suas configuracoes)\ne depois apague este arquivo.\n' "$NOVA" > "$SENHA_ARQ"
      chmod 600 "$SENHA_ARQ"
      verde "Senha de fábrica trocada por uma aleatória."
      echo "Ela NÃO aparece aqui na tela. Para ver:  cat $SENHA_ARQ"
    else
      falha "Não consegui trocar a senha de fábrica (HTTP $CODIGO). O painel NÃO será publicado."
    fi
    unset NOVA TOKEN
  else
    amarelo "A senha de fábrica não entra mais: o admin já tem senha própria. Nada a fazer."
  fi
else
  echo "Atualização: usuários e senhas existentes foram mantidos."
fi

# Trava de segurança: o painel só vai para a internet se a senha de fábrica NÃO funcionar mais.
FABRICA="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$API/api/login" -H 'Content-Type: application/json' \
    -d '{"username":"admin","password":"Hello,world!","id":"conferencia","uuid":"conferencia"}')"
[ "$FABRICA" != 200 ] || falha "A senha de fábrica ainda funciona. O painel NÃO será publicado."

# ---------------------------------------------------------------- 6. HTTPS pelo Nginx
titulo "6/6 Painel em HTTPS"
publicar_https() {
  command -v nginx >/dev/null 2>&1 || { amarelo "Nginx não encontrado: painel fica só local."; return 0; }
  command -v certbot >/dev/null 2>&1 || { amarelo "certbot não encontrado: painel fica só local."; return 0; }

  local ip_publico ip_dns
  ip_publico="$(curl -fsS --max-time 6 https://api.ipify.org 2>/dev/null || true)"
  # "|| true": sem registro DNS o getent devolve erro, e isso não pode derrubar o script.
  ip_dns="$(getent ahostsv4 "$ENDERECO" 2>/dev/null | awk 'NR==1{print $1}' || true)"
  if [ -z "$ip_dns" ] || [ -z "$ip_publico" ] || [ "$ip_dns" != "$ip_publico" ]; then
    amarelo "O DNS de $ENDERECO ainda não aponta para este servidor (DNS: ${ip_dns:-sem registro}, servidor: ${ip_publico:-?})."
    echo "Crie o registro A (na Cloudflare, nuvem CINZA) e rode este script de novo: ele continua daqui."
    return 0
  fi

  # SELinux: o Nginx precisa de permissão para falar com a porta 21114 (só essa porta, nada global).
  if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" = Enforcing ]; then
    if ! getsebool httpd_can_network_connect 2>/dev/null | grep -q ' on$'; then
      if command -v semanage >/dev/null 2>&1; then
        semanage port -a -t http_port_t -p tcp 21114 2>/dev/null \
          || semanage port -m -t http_port_t -p tcp 21114 2>/dev/null || true
        echo "SELinux: porta 21114 liberada para o Nginx."
      else
        amarelo "SELinux ativo e sem o comando semanage: se o painel der erro 502, instale policycoreutils-python-utils e rode de novo."
      fi
    fi
  fi

  mkdir -p "$ACME_DIR/.well-known/acme-challenge"
  local cert="/etc/letsencrypt/live/$ENDERECO/fullchain.pem"
  # Se já existe uma configuração nossa, guarda uma cópia (o Nginx só carrega arquivos terminados em .conf).
  local anterior=""
  if [ -f "$NGINX_CONF" ]; then
    anterior="$NGINX_CONF.bak-$AGORA"
    cp "$NGINX_CONF" "$anterior"
  fi

  escrever_conf() { # $1 = so80 | completo
    {
      cat <<EOF
# Somos STI Acesso Remoto - painel e API em HTTPS (gerado por instalar-painel.sh)
limit_req_zone \$binary_remote_addr zone=sti_login:10m rate=10r/m;

server {
    listen 80;
    listen [::]:80;
    server_name $ENDERECO;

    location /.well-known/acme-challenge/ { root $ACME_DIR; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
      if [ "$1" = completo ]; then cat <<EOF

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $ENDERECO;

    ssl_certificate     /etc/letsencrypt/live/$ENDERECO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$ENDERECO/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header Referrer-Policy no-referrer always;

    client_max_body_size 4m;

    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;

    # Tentativas de login limitadas por IP (10 por minuto) contra adivinhação de senha
    location = /api/login {
        limit_req zone=sti_login burst=10 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:21114;
    }

    location = / { return 302 /ui/; }

    location / {
        proxy_pass http://127.0.0.1:21114;
        proxy_http_version 1.1;
        proxy_read_timeout 120s;
    }
}
EOF
      fi
    } > "$NGINX_CONF"
  }

  desfazer() {
    if [ -n "$anterior" ]; then cp "$anterior" "$NGINX_CONF"; else mv "$NGINX_CONF" "$NGINX_CONF.com-erro-$AGORA"; fi
    if nginx -t >/dev/null 2>&1; then systemctl reload nginx || true; fi
  }

  if [ ! -f "$cert" ]; then
    escrever_conf so80
    if ! nginx -t 2>/tmp/sti-nginx-teste.log; then
      cat /tmp/sti-nginx-teste.log; desfazer
      amarelo "O Nginx recusou a configuração nova: ela foi retirada e os outros sites não foram afetados."
      return 0
    fi
    systemctl reload nginx
    if ! certbot certonly --webroot -w "$ACME_DIR" -d "$ENDERECO" -n --deploy-hook "systemctl reload nginx"; then
      amarelo "O certbot não emitiu o certificado. O painel continua só local; veja a mensagem acima e rode de novo."
      return 0
    fi
  fi

  escrever_conf completo
  if ! nginx -t 2>/tmp/sti-nginx-teste.log; then
    cat /tmp/sti-nginx-teste.log; desfazer
    amarelo "O Nginx recusou a configuração HTTPS: ela foi retirada e os outros sites não foram afetados."
    return 0
  fi
  systemctl reload nginx

  # O reload do Nginx leva um instante: nos primeiros milissegundos ainda responde a configuração
  # antiga (com o certificado de outro site). Por isso a conferência espera e tenta algumas vezes.
  local codigo=""
  for _ in $(seq 1 10); do
    sleep 2
    codigo="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$ENDERECO/ui/" 2>/dev/null || true)"
    [ "$codigo" = 200 ] && break
  done
  if [ "$codigo" = 200 ]; then
    verde "Painel publicado: https://$ENDERECO/"
  else
    amarelo "Configuração aplicada, mas https://$ENDERECO/ui/ respondeu HTTP ${codigo:-sem resposta}. Me envie esta saída."
  fi
}
publicar_https

# ---------------------------------------------------------------- resumo
titulo "Resumo"
docker ps --filter name=sti- --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo
echo "  Endereço (Host) ....: $ENDERECO"
echo "  Chave pública (Key) : $CHAVE_DEPOIS"
echo "  Painel .............: https://$ENDERECO/   (depois do DNS e do certificado)"
echo "  Só-logado ..........: $(grep -E '^STI_SO_LOGADO=' "$DESTINO/.env" | cut -d= -f2)   (mude em $DESTINO/.env e rode: docker compose up -d)"
[ -f "$SENHA_ARQ" ] && echo "  Senha inicial ......: cat $SENHA_ARQ"
echo
echo "Cópia de segurança desta execução: $BKP"
