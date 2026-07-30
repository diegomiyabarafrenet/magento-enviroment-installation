# Instalação do ambiente Magento (Windows + WSL2 + Docker)

Este repositório contém tudo que você precisa para instalar, do zero, um ambiente de desenvolvimento Magento no Windows, usando WSL2 + Docker Desktop + a stack oficial do [markshust/docker-magento](https://github.com/markshust/docker-magento).

**Este tutorial assume que você nunca usou WSL, Docker ou Linux antes.** Siga os passos na ordem, sem pular nenhum. Cada comando pode ser copiado e colado exatamente como está.

O processo tem 2 partes:
- **Parte 1** é feita no Windows (PowerShell + Docker Desktop).
- **Parte 2** é feita dentro do Ubuntu (que vai rodar dentro do Windows via WSL2), e é onde o script `install.sh` faz praticamente tudo sozinho.

O `install.sh` pode ser rodado quantas vezes forem necessárias, mesmo depois de já ter uma versão do Magento instalada: ele **detecta sozinho** o que já está configurado (git, chave SSH, outro ambiente rodando nas portas 80/443) e pula essas etapas automaticamente, pedindo só o que ainda falta.

---

## Parte 1 — Preparar o Windows

> Se você já fez esta parte antes (em outra instalação), pode pular direto para a **Parte 2**.

### 1.1. Instalar o WSL2 + Ubuntu

1. Clique no menu Iniciar do Windows, digite `PowerShell`, clique com o botão direito em **Windows PowerShell** e escolha **Executar como administrador**.
2. Cole o comando abaixo e pressione Enter:
   ```
   wsl --install -d Ubuntu-26.04
   ```
   > Se der erro dizendo que essa distribuição não foi encontrada, rode `wsl --list --online` para ver o nome exato da versão do Ubuntu disponível na sua máquina e use esse nome no lugar de `Ubuntu-26.04`.
3. Aguarde o download e a instalação terminarem. Pode levar alguns minutos.
4. Se o Windows pedir para reiniciar o computador, reinicie e depois abra o **Ubuntu** pelo menu Iniciar.
5. Na primeira vez que o Ubuntu abrir, ele vai pedir para você criar um usuário Linux:
   - **Enter new UNIX username:** digite um nome de usuário (sem espaços, ex: `diego`) e pressione Enter.
   - **New password:** digite uma senha (ela não aparece na tela enquanto você digita, isso é normal) e pressione Enter.
   - **Retype new password:** digite a mesma senha de novo e pressione Enter.
   > Essa conta é só do Linux, não tem nada a ver com sua conta do Windows. Guarde essa senha, você vai precisar dela sempre que rodar comandos com `sudo`.
6. Você deve ver um terminal do Ubuntu pronto para uso (algo como `diego@DESKTOP:~$`). Pode deixar essa janela aberta.

### 1.2. Instalar o Docker Desktop

1. Baixe o Docker Desktop para Windows em: https://www.docker.com/products/docker-desktop/
2. Execute o instalador baixado e siga o assistente (pode deixar todas as opções no padrão).
3. Quando terminar, reinicie o computador se for solicitado.
4. Abra o **Docker Desktop** (menu Iniciar). Aguarde o ícone da baleia na barra de tarefas ficar parado (sem animação) — isso indica que o Docker terminou de iniciar.

### 1.3. Ativar a integração do Docker com o WSL

1. Dentro do Docker Desktop, clique na engrenagem (**Settings**) no canto superior direito.
2. Vá em **Resources** → **WSL Integration**.
3. Ative o botão **"Enable integration with my default WSL distro"**.
4. Logo abaixo, na lista de distribuições, ative o botão ao lado de **Ubuntu-26.04**.
5. Clique em **Apply & Restart**.

### 1.4. Garantir memória suficiente para o Docker

O ambiente Magento precisa de pelo menos **6GB de RAM** alocados para o Docker. Para garantir isso:

1. Ainda em **Settings**, vá em **Resources** → **Advanced**.
2. Configure **Memory** para pelo menos `8 GB` e clique em **Apply & Restart**.

Se essa tela não existir na sua versão do Docker Desktop (em algumas versões isso é controlado só pelo WSL), crie/edite o arquivo `%UserProfile%\.wslconfig` no Windows (pelo Bloco de Notas, por exemplo) com o seguinte conteúdo:
```
[wsl2]
memory=8GB
```
Depois, no PowerShell, rode `wsl --shutdown` e abra o Ubuntu de novo.

---

## Parte 2 — Instalar o Magento (dentro do Ubuntu)

A partir daqui, tudo é feito dentro da janela do **Ubuntu** (não no PowerShell).

### 2.1. Instalar o Git (se necessário)

```bash
sudo apt update && sudo apt install -y git
```
(vai pedir a senha do Linux que você criou no passo 1.1 — digite e pressione Enter; a senha não aparece na tela, é normal)

### 2.2. Baixar este repositório

Como este repositório é privado, você precisa estar logado no GitHub (no navegador do Windows) e o Diego precisa ter adicionado seu usuário como colaborador do repositório. O jeito mais simples é baixar o ZIP pelo navegador (no Windows) e depois mover a pasta para dentro do Ubuntu.

1. **No Windows**, com o navegador já logado no GitHub, acesse:
   👉 https://github.com/diegomiyabarafrenet/magento-enviroment-installation
2. Clique no botão verde **"Code"** → **"Download ZIP"**. O arquivo `magento-enviroment-installation-main.zip` vai para a sua pasta **Downloads**.
3. **Ainda no Windows**, extraia o ZIP: clique com o botão direito no arquivo baixado → **"Extrair Tudo..."** → **Extrair**. Isso cria a pasta `magento-enviroment-installation-main` dentro de Downloads.
4. Descubra seu nome de usuário do Windows: abra o **Explorador de Arquivos** e veja o nome da pasta em `Este Computador → Disco Local (C:) → Users → <SEU_USUARIO>`.
5. Volte para o terminal do **Ubuntu** (não o PowerShell) e mova a pasta extraída do Windows para dentro do Ubuntu com o comando abaixo — troque `<SEU_USUARIO>` pelo nome que você viu no passo 4:
   ```bash
   mkdir -p ~/Sites
   mv "/mnt/c/Users/<SEU_USUARIO>/Downloads/magento-enviroment-installation-main" ~/Sites/magento-enviroment-installation
   ```
   > O Windows enxerga seus discos dentro do WSL em `/mnt/c/`, `/mnt/d/`, etc. Por isso o caminho começa com `/mnt/c/Users/...` — é o mesmo `C:\Users\...` do Windows, só que "traduzido" para o formato do Linux.

Depois de mover, entre na pasta (agora já dentro do Ubuntu):
```bash
cd ~/Sites/magento-enviroment-installation
```

> **Atualizações futuras:** como a pasta não é mais um clone Git (é só os arquivos extraídos do ZIP), para pegar uma versão mais nova deste repositório no futuro, repita os passos 1 a 5 baixando o ZIP de novo (pode apagar a pasta antiga antes com `rm -rf ~/Sites/magento-enviroment-installation`).

### 2.3. Rodar o instalador

```bash
chmod +x install.sh
./install.sh
```

O script vai te pedir, na ordem, apenas estas informações (tudo o resto é automático):

1. **Seu nome e e-mail do Git** — usados para configurar o `git config --global`.
2. **Geração de chave SSH** — o script cria uma chave SSH nova (se você ainda não tiver uma) e mostra a chave pública na tela. Copie essa chave e adicione em:
   👉 https://github.com/settings/keys → botão **"New SSH key"** → cole a chave → **Add SSH key**.
   Depois de adicionar, volte ao terminal e pressione **Enter** para o script continuar.
3. **Versão do Magento** — edição (padrão: `community`) e versão (padrão: `2.4.8-p1`, mas você pode digitar outra, ex: `2.4.8`, `2.4.7-p3`, etc). O projeto é criado em `~/Sites/<versao>` (ex: `~/Sites/2.4.8-p1`) e o endereço da loja é gerado automaticamente a partir da versão, no formato `dev.<versao>.com` (ex: `https://dev.2.4.8-p1.com/`).
4. **Chaves da Adobe Commerce Marketplace** — só na **primeira vez** que você instalar qualquer versão nesta máquina, o instalador do Magento vai pedir uma **Public key** e uma **Private key**. Veja a seção abaixo se você ainda não tem essas chaves. Em instalações seguintes (outras versões), isso não é pedido de novo — fica salvo automaticamente.

Durante o processo, o Linux também pode pedir sua senha (`sudo`) — normalmente só uma vez, o sudo guarda a senha em cache por alguns minutos — para adicionar o domínio local no arquivo `/etc/hosts` do WSL e para instalar a autoridade certificadora local (mkcert) no WSL. Isso é esperado, é só digitar a mesma senha do passo 1.1 (não aparece nada na tela enquanto digita).

Logo em seguida, o script tenta duas coisas no **Windows** (arquivos/repositórios separados dos do WSL, já que o navegador roda no Windows):
- Adicionar o domínio no **hosts do Windows** (sem isso o navegador não encontraria o site — erro `DNS_PROBE_FINISHED_NXDOMAIN`).
- Confiar o **certificado SSL local** (mkcert) também no Windows (sem isso o navegador mostraria aviso de "conexão não é particular").

Para cada uma dessas duas coisas, uma janela do Windows pode pedir permissão de administrador (**UAC**) — clique em **"Sim"** nas duas.

Depois disso, o script cuida sozinho de: baixar o Magento já configurado com **locale pt_BR, moeda BRL e fuso America/Sao_Paulo**, subir os containers Docker, instalar o banco de dados, configurar cache e SSL local, desativar o **login em duas etapas (2FA)** do admin (senão você não conseguiria entrar sem configurar um app autenticador) e instalar dados de exemplo (produtos, categorias e clientes fictícios). Isso pode levar de 10 a 30 minutos, dependendo da internet e do computador.

Ao final, o script mostra na tela o endereço da loja, do admin e as credenciais, e **deixa seu terminal já dentro da pasta do projeto** (`~/Sites/<versao>`), pronto para usar comandos como `bin/magento` sem precisar dar `cd` manualmente:
- O endereço da loja (ex: `https://dev.2.4.8-p1.com/`)
- O endereço do admin (ex: `https://dev.2.4.8-p1.com/admin/`)
- O usuário e senha de admin gerados (login simples, sem 2FA)

### 2.4. Como conseguir as chaves da Adobe Commerce Marketplace

Essas chaves são gratuitas e servem para o Composer conseguir baixar os arquivos do Magento. Se você ainda não tem uma conta:

1. Acesse https://commercemarketplace.adobe.com/ e clique em **Sign Up** (ou faça login se já tiver uma conta Adobe).
2. Depois de logado, acesse https://commercemarketplace.adobe.com/customer/accessKeys/
3. Clique em **Create A New Access Key**, dê um nome qualquer (ex: `meu-notebook`) e confirme.
4. Anote o **Public Key** e o **Private Key** gerados — são eles que o instalador vai pedir.

---

## Comandos úteis depois de instalado

Dentro da pasta do projeto (`~/Sites/<versao>`, ex: `~/Sites/2.4.8-p1`):

| Comando | O que faz |
|---|---|
| `bin/start` | Liga os containers do ambiente |
| `bin/stop` | Desliga os containers |
| `bin/restart` | Reinicia os containers |
| `bin/magento <comando>` | Roda um comando do Magento CLI dentro do container |
| `bin/bash` | Abre um terminal dentro do container da aplicação |

---

## Troubleshooting

**"Nao consegui falar com o Docker" ao rodar o install.sh**
Abra o Docker Desktop no Windows e espere o ícone da baleia parar de animar antes de rodar o script de novo.

**Erro sobre WSL Integration / distro não aparece no Docker Desktop**
Volte no passo 1.3 e confirme que a distro `Ubuntu-26.04` está marcada em Settings → Resources → WSL Integration.

**Erro de memória insuficiente (menos de 6GB)**
Siga o passo 1.4 para aumentar a memória do Docker/WSL e rode `wsl --shutdown` no PowerShell antes de tentar de novo.

**Erro de porta 80/443 já em uso (ou o script avisa que outro ambiente está rodando)**
Isso acontece quando você já tem outra versão do Magento instalada e ligada ao mesmo tempo. Só um ambiente pode usar as portas 80/443 por vez. O `install.sh` detecta isso sozinho e avisa antes de continuar; se quiser resolver manualmente, entre na pasta da versão antiga (`~/Sites/<versao-antiga>`) e rode `bin/stop` antes de instalar/ligar outra versão.

**Erro de autenticação da Adobe Commerce Marketplace (401/403 ao baixar pacotes)**
Confira se copiou a Public key e a Private key corretamente (sem espaços extras) em https://commercemarketplace.adobe.com/customer/accessKeys/. Se necessário, gere um novo par de chaves e rode `./install.sh` novamente.

**Navegador não encontra o site (`DNS_PROBE_FINISHED_NXDOMAIN` ou "Não é possível acessar esse site")**
O `install.sh` edita dois arquivos de hosts diferentes: o do WSL (usado só por comandos rodados dentro do Ubuntu) e o do Windows (usado pelo navegador). Se o passo automático do Windows falhar (ou você tiver pulado a janela de permissão de administrador), adicione manualmente:
1. Abra o **Bloco de Notas como Administrador** (pesquise "Bloco de Notas" no menu Iniciar, clique com o botão direito → "Executar como administrador").
2. Arquivo → Abrir → digite `C:\Windows\System32\drivers\etc\hosts` (troque o filtro de tipo de arquivo para "Todos os arquivos").
3. Adicione uma linha no final: `127.0.0.1 dev.<versao>.com` (ex: `127.0.0.1 dev.2.4.8-p1.com`).
4. Salve e recarregue a página no navegador.

**Navegador mostra aviso de certificado inseguro/não confiável ("A conexão não é particular")**

O `install.sh` tenta confiar o certificado local automaticamente no Windows, mas se esse passo falhar (ou a janela de permissão de administrador tiver sido pulada), importe manualmente. **Atenção:** o mkcert (ferramenta usada pelo docker-magento para gerar o certificado local) nunca cria um arquivo chamado exatamente `rootCA.crt` — se você procurar por esse nome exato vai dar "arquivo não encontrado" mesmo o certificado tendo sido gerado normalmente. O arquivo real fica em `$(mkcert -CAROOT)/rootCA.pem` (por padrão `~/.local/share/mkcert/rootCA.pem`).

1. Dentro do Ubuntu, descubra o caminho real do certificado:
   ```bash
   mkcert -CAROOT
   ls "$(mkcert -CAROOT)"
   ```
   Você deve ver um arquivo `rootCA.pem` (e `rootCA-key.pem`) dentro dessa pasta. Se o comando `mkcert` não existir ou a pasta estiver vazia, veja o item **"O certificado realmente não foi gerado"** logo abaixo antes de continuar.
2. Copie o conteúdo do certificado (`cat "$(mkcert -CAROOT)/rootCA.pem"`), ou copie o arquivo para o Windows. Ele fica acessível em `\\wsl.localhost\Ubuntu-26.04\home\<seu-usuario>\.local\share\mkcert\rootCA.pem` (troque `<seu-usuario>` pelo seu usuário do Linux).
3. No Windows, pressione `Win + R`, digite `certmgr.msc` e pressione Enter.
4. Vá em **Autoridades de Certificação Raiz Confiáveis** → **Certificados** → botão direito → **Todas as tarefas** → **Importar**.
5. No seletor de arquivo, troque o filtro de tipo para "Todos os arquivos" e selecione o `rootCA.pem` copiado no passo 2 (o Windows importa normalmente mesmo com extensão `.pem`).
6. Feche e reabra o navegador.

**O certificado realmente não foi gerado (mkcert não existe / pasta vazia)**

Se `mkcert -CAROOT` der erro de comando não encontrado, ou a pasta existir mas estiver vazia, o passo de SSL do `bin/setup` não rodou até o fim (geralmente por uma falha silenciosa de rede/sudo durante a instalação do mkcert). Para gerar o certificado manualmente:
1. Entre na pasta do projeto (`cd ~/Sites/<versao>`, ex: `cd ~/Sites/2.4.8-p1`).
2. Rode `bin/setup-ssl <dominio>` (ex: `bin/setup-ssl dev.2.4.8-p1.com`) — esse comando refaz só a parte de certificado SSL, sem reinstalar o Magento inteiro.
3. Confirme que o certificado foi criado com `mkcert -CAROOT` e `ls "$(mkcert -CAROOT)"` (deve aparecer `rootCA.pem`).
4. Repita os passos 2 a 6 da seção acima para importar no Windows.

**Depois de reiniciar o WSL/PC, o site para de abrir (domínio não resolve)**
Tanto o `/etc/hosts` do WSL quanto (mais raramente) o hosts do Windows podem perder a entrada depois de reiniciar. No WSL, adicione de novo com:
```bash
echo "127.0.0.1 ::1 dev.<versao>.com" | sudo tee -a /etc/hosts
```
Se o navegador continuar sem encontrar o site, siga também o passo manual do Windows descrito no item acima.

**Erro ao subir os containers mencionando "mount" ou "mountpoint" (grunt-config.json ou similar)**
É uma instabilidade conhecida do Docker Desktop com WSL2 ao recriar containers. Normalmente resolve rodando de novo:
```bash
bin/restart
```
Se persistir, feche o Docker Desktop, abra de novo e tente uma vez mais.

**Quero recomeçar do zero**
Apague a pasta do projeto (`~/Sites/<versao>`) e rode `./install.sh` de novo a partir da pasta deste repositório.
