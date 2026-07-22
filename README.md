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

Como este repositório é privado, você precisa estar autenticado no GitHub para cloná-lo. Peça para o Diego adicionar seu usuário do GitHub como colaborador do repositório e escolha uma das opções:

- **Opção A (recomendada, via HTTPS com token):** rode `git clone https://github.com/diegomiyabarafrenet/magento-enviroment-installation.git` e, quando pedir usuário/senha, use seu usuário do GitHub e um [Personal Access Token](https://github.com/settings/tokens) no lugar da senha.
- **Opção B (via SSH):** se você já tem uma chave SSH cadastrada no GitHub, rode:
  ```bash
  git clone git@github.com:diegomiyabarafrenet/magento-enviroment-installation.git
  ```

Depois de clonar, entre na pasta:
```bash
cd magento-enviroment-installation
```

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

Durante o processo, o Linux também pode pedir sua senha (`sudo`) uma vez, para adicionar o domínio local no arquivo `/etc/hosts` — isso é esperado, é só digitar a mesma senha do passo 1.1 (não aparece nada na tela enquanto digita).

Depois disso, o script cuida sozinho de: baixar o Magento, subir os containers Docker, instalar o banco de dados, configurar cache/SSL local, instalar dados de exemplo (produtos, categorias e clientes fictícios) e deixar tudo pronto para uso. Isso pode levar de 10 a 30 minutos, dependendo da internet e do computador.

Ao final, o script mostra na tela:
- O endereço da loja (ex: `https://dev.2.4.8-p1.com/`)
- O endereço do admin (ex: `https://dev.2.4.8-p1.com/admin/`)
- O usuário e senha de admin gerados

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

**Navegador mostra aviso de certificado inseguro/não confiável**
Isso é esperado na primeira vez, pois o certificado SSL é gerado localmente (autoassinado). Duas opções:
- Clique em "Avançado" → "Continuar mesmo assim" no aviso do navegador (mais simples, mas o aviso reaparece em outros navegadores).
- Para remover o aviso definitivamente, importe o certificado raiz gerado pelo `mkcert` no Windows: dentro do Ubuntu rode `mkcert -CAROOT` para achar o caminho do arquivo `rootCA.pem`, copie esse arquivo para o Windows (ele fica acessível em `\\wsl.localhost\Ubuntu-26.04\...`) e importe-o em **Autoridades de Certificação Raiz Confiáveis** pelo `certmgr.msc` do Windows.

**Erro de autenticação da Adobe Commerce Marketplace (401/403 ao baixar pacotes)**
Confira se copiou a Public key e a Private key corretamente (sem espaços extras) em https://commercemarketplace.adobe.com/customer/accessKeys/. Se necessário, gere um novo par de chaves e rode `./install.sh` novamente.

**Depois de reiniciar o WSL/PC, o site para de abrir (domínio não resolve)**
O `/etc/hosts` do WSL é regenerado automaticamente a cada reinício, o que pode apagar a linha do seu domínio. Adicione-a de novo com:
```bash
echo "127.0.0.1 ::1 dev.<versao>.com" | sudo tee -a /etc/hosts
```

**Erro ao subir os containers mencionando "mount" ou "mountpoint" (grunt-config.json ou similar)**
É uma instabilidade conhecida do Docker Desktop com WSL2 ao recriar containers. Normalmente resolve rodando de novo:
```bash
bin/restart
```
Se persistir, feche o Docker Desktop, abra de novo e tente uma vez mais.

**Quero recomeçar do zero**
Apague a pasta do projeto (`~/Sites/<versao>`) e rode `./install.sh` de novo a partir da pasta deste repositório.
