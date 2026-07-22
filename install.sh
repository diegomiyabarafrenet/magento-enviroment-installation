#!/usr/bin/env bash
#
# Instalador de ambiente Magento (WSL2 + Docker + markshust/docker-magento).
# Rode este script de dentro do Ubuntu (WSL2), nunca no PowerShell/CMD do Windows.
#
# Pode ser rodado varias vezes na mesma distro WSL para instalar versoes
# diferentes do Magento lado a lado (cada versao ganha sua propria pasta em
# ~/Sites). Configuracoes ja feitas (git, chave SSH) nao sao pedidas de novo.
#
set -euo pipefail

DOCKER_MAGENTO_REPO="https://github.com/markshust/docker-magento.git"
DEFAULT_EDITION="community"
DEFAULT_VERSION="2.4.8-p1"

color() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info()  { color "0;34" "==> $1"; }
warn()  { color "0;33" "!!  $1"; }
ok()    { color "0;32" "OK  $1"; }
die()   { color "0;31" "ERRO: $1"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Pre-checagens de ambiente
# ---------------------------------------------------------------------------
info "Checando pre-requisitos..."

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  warn "Este script foi feito para rodar dentro do WSL2 (Ubuntu). Ambientes diferentes podem ter comportamento inesperado."
fi

command -v git >/dev/null 2>&1 || die "git nao encontrado. Rode: sudo apt update && sudo apt install -y git"

if ! docker info >/dev/null 2>&1; then
  die "Nao consegui falar com o Docker. Abra o Docker Desktop no Windows, espere ele iniciar completamente e rode este script de novo."
fi

MEM_BYTES=$(docker info -f '{{.MemTotal}}' 2>/dev/null || echo 0)
MEM_MB=$(( MEM_BYTES / 1000000 ))
if (( MEM_MB < 6227 )); then
  die "O Docker Desktop precisa de pelo menos 6GB de RAM alocados (Settings > Resources > Advanced). Atualmente: ${MEM_MB}MB."
fi

ok "Pre-requisitos OK."

# ---------------------------------------------------------------------------
# 2. Identidade do Git (unica interacao obrigatoria nº1)
# ---------------------------------------------------------------------------
echo
info "Configuracao do Git"
CURRENT_NAME="$(git config --global user.name || true)"
CURRENT_EMAIL="$(git config --global user.email || true)"

if [ -z "$CURRENT_NAME" ]; then
  read -r -p "Seu nome (aparecera nos commits do Git): " GIT_NAME
  git config --global user.name "$GIT_NAME"
else
  ok "Nome do Git ja configurado: $CURRENT_NAME"
fi

if [ -z "$CURRENT_EMAIL" ]; then
  read -r -p "Seu e-mail (o mesmo da sua conta do GitHub): " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
else
  ok "E-mail do Git ja configurado: $CURRENT_EMAIL"
fi

# ---------------------------------------------------------------------------
# 3. Chave SSH para o GitHub (unica interacao obrigatoria nº2: pausa)
# ---------------------------------------------------------------------------
echo
info "Chave SSH para o GitHub"
SSH_KEY="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY" ]; then
  ok "Ja existe uma chave SSH em $SSH_KEY (de uma instalacao anterior), nenhuma acao necessaria."
else
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "${CURRENT_EMAIL:-${GIT_EMAIL:-}}" -f "$SSH_KEY" -N ""

  echo
  warn "Copie a chave publica abaixo e adicione na sua conta do GitHub em:"
  warn "https://github.com/settings/keys  (botao 'New SSH key')"
  echo
  cat "$SSH_KEY.pub"
  echo
  read -r -p "Depois de adicionar a chave no GitHub, pressione Enter para continuar... " _
fi

# ---------------------------------------------------------------------------
# 4. Versao do Magento (unica interacao obrigatoria nº3)
# ---------------------------------------------------------------------------
echo
info "Versao do Magento"
read -r -p "Edicao [community/enterprise] (padrao: ${DEFAULT_EDITION}): " EDITION
EDITION=${EDITION:-$DEFAULT_EDITION}

read -r -p "Versao do Magento (padrao: ${DEFAULT_VERSION}): " VERSION
VERSION=${VERSION:-$DEFAULT_VERSION}

DOMAIN="dev.${VERSION}.com"
PROJECT_DIR="$HOME/Sites/${VERSION}"

ok "Vou instalar Magento ${EDITION} ${VERSION} em https://${DOMAIN}/"

# ---------------------------------------------------------------------------
# 5. Checar se ja existe outro ambiente rodando nas portas 80/443
#    (so um ambiente docker-magento pode ficar de pe por vez nessas portas,
#    mesmo instalando varias versoes na mesma distro WSL)
# ---------------------------------------------------------------------------
RUNNING_ON_PORTS="$(docker ps --filter "publish=80" --filter "publish=443" --format '{{.Names}}' 2>/dev/null | sort -u || true)"
if [ -n "$RUNNING_ON_PORTS" ]; then
  echo
  warn "Ja existe um ambiente Magento rodando e usando as portas 80/443:"
  warn "$RUNNING_ON_PORTS"
  warn "So um ambiente pode ficar ligado por vez nessas portas."
  warn "Va na pasta do projeto antigo (~/Sites/<versao-antiga>) e rode 'bin/stop' antes de continuar."
  read -r -p "Ja parou o ambiente antigo? Pressione Enter para continuar, ou Ctrl+C para cancelar... " _
fi

# ---------------------------------------------------------------------------
# 6. Clonar o docker-magento oficial (markshust) e baixar o Magento
#    (a partir daqui, tudo automatico -- exceto o prompt de chaves da Adobe
#    Commerce Marketplace, que o proprio docker-magento faz em bin/download)
# ---------------------------------------------------------------------------
echo
info "Clonando docker-magento (markshust) em ${PROJECT_DIR}..."
mkdir -p "$(dirname "$PROJECT_DIR")"

if [ -d "$PROJECT_DIR" ]; then
  die "A pasta ${PROJECT_DIR} ja existe. Remova-a ou escolha outra versao antes de rodar de novo."
fi

git clone "$DOCKER_MAGENTO_REPO" "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo
info "Baixando o Magento ${EDITION} ${VERSION} via Composer..."
warn "Agora o instalador vai pedir suas chaves (Public key / Private key) da Adobe Commerce Marketplace."
warn "Se voce ainda nao tem uma conta, veja o passo a passo no README.md deste repositorio (secao 'Adobe Commerce Marketplace')."
echo
bin/download "$EDITION" "$VERSION"

# ---------------------------------------------------------------------------
# 7. Subir os containers e instalar o Magento (100% automatico)
# ---------------------------------------------------------------------------
echo
info "Instalando o Magento (containers, banco, cache, SSL local)..."
bin/setup "$DOMAIN"

# ---------------------------------------------------------------------------
# 8. Dados de exemplo (sample data) -- sempre "sim", sem perguntar
# ---------------------------------------------------------------------------
echo
info "Instalando dados de exemplo (produtos, categorias, clientes ficticios)..."
bin/clinotty bin/magento sample-data:deploy
bin/clinotty composer update --no-interaction
bin/clinotty bin/magento setup:upgrade
bin/clinotty bin/magento indexer:reindex
bin/clinotty bin/magento cache:flush

# ---------------------------------------------------------------------------
# 9. Resumo final
# ---------------------------------------------------------------------------
ADMIN_USER="$(grep -m1 '^MAGENTO_ADMIN_USER=' env/magento.env | cut -d= -f2)"
ADMIN_PASSWORD="$(grep -m1 '^MAGENTO_ADMIN_PASSWORD=' env/magento.env | cut -d= -f2)"

echo
ok "Instalacao concluida!"
echo
echo "Loja:   https://${DOMAIN}/"
echo "Admin:  https://${DOMAIN}/admin/"
echo "Usuario admin: ${ADMIN_USER}"
echo "Senha admin:   ${ADMIN_PASSWORD}"
echo
echo "Se o navegador mostrar aviso de certificado inseguro, veja a secao"
echo "'Certificado SSL nao confiavel' no README.md deste repositorio."
