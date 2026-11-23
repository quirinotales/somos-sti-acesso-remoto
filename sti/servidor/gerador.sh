#!/usr/bin/env bash
# Somos STI Acesso Remoto - gerador de instaladores
#
# O gerador e uma pagina que dispara a compilacao do programa no SEU GitHub
# (GitHub Actions) e recebe os instaladores prontos. Ele so precisa ficar ligado
# enquanto voce estiver gerando uma versao.
#
# Uso (como root, em /opt/sti-acesso-remoto):
#     ./gerador.sh configurar   # 1a vez: pede usuario e token do GitHub
#     ./gerador.sh iniciar      # liga a pagina e libera a porta
#     ./gerador.sh parar        # desliga a pagina e fecha a porta
#     ./gerador.sh status

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_ARQ="$DIR/.env.gerador"
# O arquivo .env desta pasta pertence ao servidor (versão, endereço, só-logado): o gerador NÃO o usa.
# Tudo do gerador, inclusive a porta, fica em .env.gerador.
DC=(docker compose --env-file "$ENV_ARQ" -f "$DIR/docker-compose.gerador.yml" -p sti-gerador)
cd "$DIR"

vermelho() { printf '\033[1;31m%s\033[0m\n' "$*"; }
verde()    { printf '\033[1;32m%s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { vermelho "Rode como root (ou com sudo)."; exit 1; }

porta() {
  local p=8000
  [ -f "$ENV_ARQ" ] && p="$(grep -E '^GERADOR_PORTA=' "$ENV_ARQ" | cut -d= -f2 || true)"
  echo "${p:-8000}"
}

firewall() { # $1 = abrir | fechar
  local p; p="$(porta)"
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    if [ "$1" = abrir ]; then ufw allow "$p/tcp" comment 'STI gerador' >/dev/null
    else ufw delete allow "$p/tcp" >/dev/null 2>&1 || true; fi
  elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    if [ "$1" = abrir ]; then firewall-cmd --add-port="$p/tcp" >/dev/null
    else firewall-cmd --remove-port="$p/tcp" >/dev/null 2>&1 || true; fi
  fi
}

aleatorio() { head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

configurar() {
  local padrao_host="" usuario token host p
  [ -f "$DIR/endereco.txt" ] && padrao_host="$(cat "$DIR/endereco.txt")"

  echo "Antes de continuar voce precisa ter, no GitHub:"
  echo "  - um fork do repositorio bryangerlach/rdgen na sua conta"
  echo "  - um token 'fine-grained' so para esse fork, com Actions e Workflows em Read and write"
  echo
  read -r -p "Usuario do GitHub (dono do fork): " usuario
  read -r -s -p "Token do GitHub (nao aparece na tela): " token; echo
  read -r -p "Endereco publico desta maquina [${padrao_host}]: " host
  host="${host:-$padrao_host}"
  read -r -p "Porta da pagina do gerador [8000]: " p
  p="${p:-8000}"

  if [ -z "$usuario" ] || [ -z "$token" ] || [ -z "$host" ]; then
    vermelho "Usuario, token e endereco sao obrigatorios."; exit 1
  fi
  case "$p" in ''|*[!0-9]*) vermelho "Porta invalida."; exit 1;; esac

  local senha_zip chave_django url
  senha_zip="$(aleatorio)"
  chave_django="$(aleatorio)"
  url="http://${host}:${p}"

  umask 077
  cat > "$ENV_ARQ" <<EOF
SECRET_KEY=${chave_django}
GHUSER=${usuario}
GHBEARER=${token}
GENURL=${url}
ZIP_PASSWORD=${senha_zip}
GHBRANCH=master
PROTOCOL=http
REPONAME=rdgen
GERADOR_PORTA=${p}
EOF
  chmod 600 "$ENV_ARQ"

  verde "Configuracao salva em $ENV_ARQ (somente root le)."
  echo
  echo "Agora cadastre DOIS segredos no fork (github.com/${usuario}/rdgen >"
  echo "Settings > Secrets and variables > Actions > New repository secret):"
  echo
  echo "  Nome: GENURL"
  echo "  Valor: ${url}"
  echo
  echo "  Nome: ZIP_PASSWORD"
  echo "  Valor: ${senha_zip}"
  echo
  echo "Depois rode: ./gerador.sh iniciar"
}

iniciar() {
  [ -f "$ENV_ARQ" ] || { vermelho "Rode primeiro: ./gerador.sh configurar"; exit 1; }
  mkdir -p "$DIR/gerador/exe" "$DIR/gerador/png" "$DIR/gerador/temp_zips"
  "${DC[@]}" pull gerador
  "${DC[@]}" up -d gerador
  firewall abrir
  local url; url="$(grep -E '^GENURL=' "$ENV_ARQ" | cut -d= -f2-)"
  verde "Gerador ligado: ${url}"
  echo "A porta $(porta)/tcp tambem precisa estar encaminhada no roteador/nuvem,"
  echo "porque o GitHub devolve os instaladores por ela."
  echo "Quando terminar de baixar os instaladores: ./gerador.sh parar"
}

parar() {
  "${DC[@]}" stop gerador >/dev/null 2>&1 || true
  "${DC[@]}" rm -f gerador >/dev/null 2>&1 || true
  firewall fechar
  verde "Gerador desligado e porta fechada. Os instaladores ja gerados continuam em $DIR/gerador/exe"
}

status() {
  docker ps --filter name=sti- --format 'table {{.Names}}\t{{.Status}}'
}

case "${1:-}" in
  configurar) configurar ;;
  iniciar)    iniciar ;;
  parar)      parar ;;
  status)     status ;;
  *) echo "Uso: $0 {configurar|iniciar|parar|status}"; exit 1 ;;
esac
