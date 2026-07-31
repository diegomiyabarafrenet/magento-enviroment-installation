#!/usr/bin/env bash
#
# Instalador de ambiente Magento (WSL2 + Docker + markshust/docker-magento).
# Rode este script de dentro do Ubuntu (WSL2), nunca no PowerShell/CMD do Windows.
#
# Pode ser rodado varias vezes na mesma distro WSL para instalar versoes
# diferentes do Magento lado a lado (cada versao ganha sua propria pasta em
# ~/Sites). Configuracoes ja feitas (git, chave SSH) nao sao pedidas de novo.
#
# RETOMAR APOS UMA FALHA: se o script morrer no meio (queda de rede,
# instabilidade do Docker Desktop, etc.), rode "./install.sh" de novo e
# responda com a MESMA versao -- ele detecta o que ja foi feito na pasta do
# projeto e continua dali, em vez de recomecar do zero ou exigir que a pasta
# seja apagada primeiro.
#
set -euo pipefail

DOCKER_MAGENTO_TEMPLATE_URL="https://raw.githubusercontent.com/markshust/docker-magento/master/lib/template"
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

EXISTING_SSH_KEY=""
for k in id_ed25519 id_rsa id_ecdsa id_dsa; do
  if [ -f "$HOME/.ssh/$k" ]; then
    EXISTING_SSH_KEY="$HOME/.ssh/$k"
    break
  fi
done

if [ -n "$EXISTING_SSH_KEY" ]; then
  ok "Ja existe uma chave SSH em $EXISTING_SSH_KEY, nenhuma acao necessaria."
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
#    mesmo instalando varias versoes na mesma distro WSL). Se o que estiver
#    rodando for o PROPRIO projeto que estamos retomando (mesma pasta), nao
#    ha conflito de verdade -- so avisamos/pausamos quando for outro projeto.
# ---------------------------------------------------------------------------
RUNNING_ON_PORTS="$(docker ps --filter "publish=80" --filter "publish=443" --format '{{.Names}}' 2>/dev/null | sort -u || true)"
if [ -n "$RUNNING_ON_PORTS" ]; then
  SAME_PROJECT=0
  while IFS= read -r cname; do
    [ -z "$cname" ] && continue
    WORKING_DIR="$(docker inspect "$cname" --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null || true)"
    if [ "$WORKING_DIR" = "$PROJECT_DIR" ]; then
      SAME_PROJECT=1
    fi
  done <<< "$RUNNING_ON_PORTS"

  if [ "$SAME_PROJECT" -eq 1 ]; then
    ok "O ambiente ja rodando nas portas 80/443 e este mesmo projeto (${PROJECT_DIR}), continuando normalmente."
  else
    echo
    warn "Ja existe um ambiente Magento rodando e usando as portas 80/443:"
    warn "$RUNNING_ON_PORTS"
    warn "So um ambiente pode ficar ligado por vez nessas portas."
    warn "Va na pasta do projeto antigo (~/Sites/<versao-antiga>) e rode 'bin/stop' antes de continuar."
    read -r -p "Ja parou o ambiente antigo? Pressione Enter para continuar, ou Ctrl+C para cancelar... " _
  fi
fi

# ---------------------------------------------------------------------------
# 6. Criar o projeto a partir do template oficial do docker-magento (markshust)
#    e baixar o Magento. Nota: o docker-magento nao se clona mais direto com
#    "git clone" -- ele usa um sparse-checkout da pasta compose/ do repo, por
#    isso reproduzimos aqui o mesmo passo do lib/onelinesetup oficial.
#    (a partir daqui, tudo automatico -- exceto o prompt de chaves da Adobe
#    Commerce Marketplace, que o proprio docker-magento faz em bin/download;
#    esse prompt so aparece na primeira instalacao desta maquina, depois fica
#    salvo globalmente em ~/.composer/auth.json e e reaproveitado sempre)
#
#    Cada sub-passo abaixo checa uma marca do que ja foi feito (em vez de so
#    checar se a pasta existe) para que rodar o script de novo depois de uma
#    falha continue dali, sem recomecar nem exigir apagar a pasta primeiro.
# ---------------------------------------------------------------------------
echo
mkdir -p "$(dirname "$PROJECT_DIR")"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

if [ -f "bin/setup" ]; then
  ok "Projeto ja existe em ${PROJECT_DIR}, retomando a instalacao dali..."
else
  info "Criando o projeto em ${PROJECT_DIR}..."
  curl -s "$DOCKER_MAGENTO_TEMPLATE_URL" | bash
fi

echo
info "Configurando locale pt_BR e moeda BRL..."
sed -i 's/^MAGENTO_LOCALE=.*/MAGENTO_LOCALE=pt_BR/' env/magento.env
sed -i 's/^MAGENTO_CURRENCY=.*/MAGENTO_CURRENCY=BRL/' env/magento.env
sed -i 's/^MAGENTO_TIMEZONE=.*/MAGENTO_TIMEZONE=America\/Sao_Paulo/' env/magento.env

if [ -f "src/bin/magento" ]; then
  ok "Magento ja foi baixado anteriormente nesta pasta, pulando o Composer."
else
  echo
  info "Baixando o Magento ${EDITION} ${VERSION} via Composer..."
  warn "Na primeira instalacao nesta maquina, o instalador vai pedir suas chaves (Public key / Private key) da Adobe Commerce Marketplace."
  warn "Se voce ainda nao tem uma conta, veja o passo a passo no README.md deste repositorio (secao 'Adobe Commerce Marketplace')."
  echo
  bin/download "$EDITION" "$VERSION"
fi

# ---------------------------------------------------------------------------
# 7. Subir os containers e instalar o Magento (100% automatico)
#    Nota: este passo pode pedir a senha do Linux (sudo) duas vezes -- para
#    adicionar o dominio local no /etc/hosts e para instalar a autoridade
#    certificadora local (mkcert) no WSL. Isso e esperado (normalmente so
#    pede a senha uma vez, o sudo guarda ela em cache por alguns minutos).
#
#    O Docker Desktop com WSL2 tem uma instabilidade conhecida ao criar os
#    containers pela primeira vez (erro mencionando "mount"/"mountpoint...
#    file exists"). Por isso tentamos ate 3 vezes, rodando "bin/restart"
#    entre as tentativas, antes de desistir -- na maioria das vezes isso
#    resolve sozinho, sem precisar de intervencao manual.
# ---------------------------------------------------------------------------
echo
info "Instalando o Magento (containers, banco, cache, certificado SSL local)..."

SETUP_OK=0
for attempt in 1 2 3; do
  if bin/setup "$DOMAIN"; then
    SETUP_OK=1
    break
  fi
  if [ "$attempt" -lt 3 ]; then
    warn "bin/setup falhou (tentativa ${attempt}/3). Isso costuma ser a instabilidade conhecida do Docker Desktop com WSL2 ao criar os containers."
    warn "Tentando recuperar com 'bin/restart' e rodando de novo..."
    bin/restart || true
    sleep 5
  fi
done

if [ "$SETUP_OK" -ne 1 ]; then
  die "bin/setup falhou apos 3 tentativas. Rode './install.sh' de novo (ele retoma a partir daqui) ou veja a secao 'Erro ao subir os containers' no README.md."
fi

echo
info "Desativando a autenticacao em duas etapas (2FA) do admin..."
bin/clinotty bin/magento module:disable Magento_TwoFactorAuth Magento_AdminAdobeImsTwoFactorAuth
bin/clinotty bin/magento cache:flush

# ---------------------------------------------------------------------------
# 8. Adicionar o dominio tambem no hosts do WINDOWS (nao so no do WSL)
#    O /etc/hosts que o bin/setup edita e o do WSL -- so vale para comandos
#    rodados dentro do proprio WSL. O navegador roda no Windows e usa o hosts
#    do Windows, que e um arquivo separado. O Docker Desktop ja encaminha as
#    portas 80/443 para o localhost do Windows automaticamente, entao so falta
#    o Windows saber resolver o dominio.
# ---------------------------------------------------------------------------
if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
  echo
  info "Adicionando ${DOMAIN} no hosts do Windows..."
  warn "Uma janela do Windows pode pedir permissao de administrador (UAC) -- clique em 'Sim'."
  PS_CMD="if (-not (Select-String -Path 'C:\\Windows\\System32\\drivers\\etc\\hosts' -Pattern '${DOMAIN}' -Quiet -SimpleMatch)) { Add-Content -Path 'C:\\Windows\\System32\\drivers\\etc\\hosts' -Value '127.0.0.1 ${DOMAIN}' }"
  ENCODED_CMD=$(printf '%s' "$PS_CMD" | iconv -t UTF-16LE | base64 -w0)
  if powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-EncodedCommand','$ENCODED_CMD'" >/dev/null 2>&1; then
    ok "Dominio adicionado no hosts do Windows."
  else
    warn "Nao consegui adicionar automaticamente no hosts do Windows."
    warn "Veja a secao 'Navegador nao encontra o site' no README.md para o passo manual."
  fi
else
  warn "Nao encontrei o powershell.exe. Se estiver no Windows, adicione manualmente '${DOMAIN}' no hosts do Windows (veja o README.md)."
fi

# ---------------------------------------------------------------------------
# 9. Confiar o certificado SSL local (mkcert) tambem no Windows
#    O bin/setup ja instala a autoridade certificadora (CA) local no WSL, o
#    que faz o certificado ser confiavel para comandos rodados dentro do
#    proprio WSL (ex: curl). O navegador roda no Windows e usa o repositorio
#    de certificados do Windows, que e separado -- sem esse passo, o
#    navegador mostraria "conexao nao e particular" mesmo com tudo certo.
#
#    Nota: o mkcert roda DENTRO do container "app" (nao no host WSL). O
#    bin/setup-ssl-ca do docker-magento faz "docker cp" do rootCA.pem de
#    dentro do container e roda "sudo mv rootCA.pem
#    /usr/local/share/ca-certificates/rootCA.crt" -- entao esse caminho fixo
#    e o correto e so deve faltar aqui se aquele "sudo mv" nao rodou (ex:
#    prompt de senha do sudo que nao foi respondido a tempo).
# ---------------------------------------------------------------------------
WSL_ROOT_CA="/usr/local/share/ca-certificates/rootCA.crt"
if [ -f "$WSL_ROOT_CA" ] && grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
  echo
  info "Confiando o certificado SSL local tambem no Windows..."
  warn "Outra janela do Windows pode pedir permissao de administrador (UAC) -- clique em 'Sim'."
  WIN_USER="$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r')"
  WIN_TEMP_WSL="/mnt/c/Users/${WIN_USER}/AppData/Local/Temp"
  CERT_FILENAME="docker-magento-rootCA-$(date +%s).crt"
  if [ -n "$WIN_USER" ] && cp "$WSL_ROOT_CA" "${WIN_TEMP_WSL}/${CERT_FILENAME}" 2>/dev/null; then
    PS_CERT_CMD="Import-Certificate -FilePath 'C:\\Users\\${WIN_USER}\\AppData\\Local\\Temp\\${CERT_FILENAME}' -CertStoreLocation Cert:\\LocalMachine\\Root"
    ENCODED_CERT_CMD=$(printf '%s' "$PS_CERT_CMD" | iconv -t UTF-16LE | base64 -w0)
    if powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-EncodedCommand','$ENCODED_CERT_CMD'" >/dev/null 2>&1; then
      ok "Certificado confiavel no Windows tambem."
    else
      warn "Nao consegui confiar o certificado automaticamente no Windows."
      warn "Veja a secao 'Certificado SSL nao confiavel' no README.md para o passo manual."
    fi
    rm -f "${WIN_TEMP_WSL}/${CERT_FILENAME}" 2>/dev/null
  else
    warn "Nao consegui copiar o certificado para o Windows. Veja a secao 'Certificado SSL nao confiavel' no README.md."
  fi
elif [ ! -f "$WSL_ROOT_CA" ]; then
  warn "Nao encontrei ${WSL_ROOT_CA}. O passo de SSL do bin/setup pode ter falhado (ex: prompt do sudo nao respondido)."
  warn "Veja a secao 'Certificado SSL nao confiavel' no README.md para gerar/localizar o certificado manualmente."
else
  warn "Nao encontrei o powershell.exe. Se estiver no Windows, veja o README.md para o passo manual de certificado."
fi

# ---------------------------------------------------------------------------
# 10. Dados de exemplo (sample data) -- sempre "sim", sem perguntar
# ---------------------------------------------------------------------------
echo
info "Instalando dados de exemplo (produtos, categorias, clientes ficticios)..."
bin/clinotty bin/magento sampledata:deploy
bin/clinotty bin/magento setup:upgrade
bin/clinotty bin/magento indexer:reindex
bin/clinotty bin/magento cache:flush

# ---------------------------------------------------------------------------
# 11. Resumo final
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
echo "Login duplo (2FA) ja vem desativado -- basta usuario e senha para entrar no admin."
echo
info "Deixando voce na pasta do projeto (${PROJECT_DIR})..."
cd "$PROJECT_DIR"
exec "${SHELL:-bash}"
