# ☁️ Deploy na Azure — MoveSync

# 🚦 Semáforo Inteligente — CitizenTech

Backend desenvolvido com Java e Spring Boot para a **Global Solution 2026 2°SEM FIAP**.
O sistema recebe leituras de sensores de trânsito (quantidade de veículos e tamanho da fila por via), decide qual via abrir e por quanto tempo, e **explica a decisão ao cidadão com IA generativa (Spring AI)**. O cidadão também pode **reportar problemas** no cruzamento (semáforo apagado, travessia insegura, falta de acessibilidade), que a IA classifica e prioriza para o gestor de trânsito.

A mesma API é consumida pelo app Mobile (React Native) da solução e oferece:

- **API RESTful** protegida por **JWT**, com dois perfis (`CIDADAO` e `GESTOR`) e documentada com Swagger.
- **Mensageria com RabbitMQ**: as leituras são publicadas como evento e processadas de forma assíncrona.
- **IA generativa (Spring AI)** integrada ao fluxo: explica cada decisão do semáforo e classifica os relatos dos cidadãos.
- **Painel de testes** (Thymeleaf) em `/dev`, para simular sensores e testar o fluxo inteiro sem montar requisições à mão.

---

## 🎯 O problema e o cidadão

Semáforos de tempo fixo dão o mesmo tempo de verde para uma rua vazia e para uma avenida congestionada, o que gera **horas perdidas no trânsito**, mais poluição e atraso para quem precisa de passagem rápida.

**Quem é beneficiado:** motoristas, motociclistas, passageiros de transporte público, pedestres e serviços de emergência.

**Como a solução ajuda:**

- O semáforo se adapta à demanda real de cada via e dá prioridade a veículos de emergência.
- Se um sensor sai do ar, o sistema volta sozinho ao tempo fixo (modo seguro), sem "congelar" o cruzamento.
- O cidadão **vê a situação do cruzamento e entende o motivo da decisão** em linguagem simples.
- O cidadão **reporta problemas** e o gestor recebe a fila de relatos já classificada por categoria e gravidade.

**ODS relacionado:** ODS 11 — Cidades e comunidades sustentáveis.

---

## 👥 MoveSync — 2TDSPO

--------------------------------
|         Nome        |   RM   |
|---------------------|--------|
| Bruno A Zanateli    | 563736 |
| Christian S Freitas | 566098 |
| Pedro P Biasolli    | 562521 |
| Rodrigo Tiezzi      | 562975 |
| Maheus E Souza      | 562532 |
--------------------------------

---
## 💼 Descrição dos Benefícios para o Negócio

- **Menos tempo parado no trânsito**: o tempo de verde acompanha o fluxo real de cada via, em vez de um ciclo fixo.
- **Menos poluição e consumo de combustível**: menos tempo de carro parado em marcha lenta nos cruzamentos.
- **Pedestres também atendidos**: semáforos de pedestre têm o ciclo ajustado pelo movimento de pessoas.
- **Manutenção mais rápida**: semáforos em manutenção e sensores offline ficam visíveis no painel.
- **Decisão baseada em dados**: o histórico de leituras e ajustes mostra onde e quando o trânsito mais trava.
- **Escalabilidade e disponibilidade**: hospedagem em nuvem (Azure App Service + Azure SQL Database) permite crescer o número de cruzamentos e leituras sem infraestrutura própria.
- **Integração facilitada**: por ser uma API REST documentada (Swagger) e com coleção Postman disponível, o sistema pode ser integrado a outros sistemas (centrais de trânsito, apps de mobilidade, painéis da prefeitura) com baixo esforço.

---

## Arquitetura

Colocar Foto da Arquitetura
---

## Variáveis

> Preencha as senhas no terminal antes de rodar os comandos (elas não ficam no repositório).

```bash
# Gerais
RESOURCE_GROUP_NAME="rg-movesync"
LOCATION="eastus2"
SQL_LOCATION="centralus"

# Web App
WEBAPP_NAME="webapp-movesync"
APP_SERVICE_PLAN="plan-movesync"
SKU="B1"
RUNTIME="TOMCAT:11.0-java21"

# Banco de Dados (Azure SQL)
SQL_SERVER_NAME="sqlserver-movesync"
SQL_DB_NAME="movesyncdb"
SQL_ADMIN_USER=""
SQL_ADMIN_PASSWORD=""

```

> **Regiões:** a assinatura Azure for Students só permite `eastus2`, `mexicocentral`, `centralus`, `southafricanorth` e `canadacentral` (consulte com `az policy assignment list --query "[].parameters" -o json`). O Web App fica em **East US 2** (única com cota de B1) e o banco em **Central US**.

---

## Comandos

> Rode **um bloco por vez** e espere a resposta (JSON) antes de colar o próximo.

### 1. Resource Group

```bash
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
```

### 2. Banco de dados (Azure SQL)

```bash
az sql server create \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$SQL_LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD"

az sql db create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --server "$SQL_SERVER_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective Basic

az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --server "$SQL_SERVER_NAME" \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255
```

> Se o `az sql db create` der `ResourceNotFound`, o servidor ainda está sendo criado: aguarde alguns segundos e rode de novo.

### 3. App Service Plan + Web App

```bash
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --sku "$SKU" \
  --is-linux

az webapp create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --plan "$APP_SERVICE_PLAN" \
  --runtime "$RUNTIME"

az resource update \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --namespace Microsoft.Web \
  --resource-type basicPublishingCredentialsPolicies \
  --name scm \
  --parent "sites/$WEBAPP_NAME" \
  --set properties.allow=true
```

### 4. Variáveis de ambiente do Web App

```bash
SPRING_DATASOURCE_URL="jdbc:sqlserver://${SQL_SERVER_NAME}.database.windows.net:1433;database=${SQL_DB_NAME};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"

az webapp config appsettings set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --settings \
    SPRING_DATASOURCE_URL="$SPRING_DATASOURCE_URL" \
    SPRING_DATASOURCE_USERNAME="$SQL_ADMIN_USER" \
    SPRING_DATASOURCE_PASSWORD="$SQL_ADMIN_PASSWORD" \
    JWT_SECRET="$JWT_SECRET" \
    ADMIN_USERNAME="$ADMIN_USERNAME" \
    ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    OPERADOR_USERNAME="$OPERADOR_USERNAME" \
    OPERADOR_PASSWORD="$OPERADOR_PASSWORD" \
  -o none

az webapp restart --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP_NAME"
```

> O `-o none` evita que o Azure CLI imprima as variáveis (com as senhas) na tela.
> Todos esses comandos também estão no script **`scripts/infra-azure.sh`**, que ainda executa o `scripts/script-bd.sql` (DDL das 6 tabelas + dados fictícios).

### 5. Release (Azure DevOps)

Na task **Deploy War to Azure App Service** da Release, selecione o **Runtime Stack `TOMCAT|11.0-java21`**. Se ficar vazio ou em Java SE, o container sobe sem encontrar o `.jar` e o site retorna **503**.

---

Agora vamos fazer login!
Se só entrarmos na página, vamos ter uma tela em branco. É necessário digitar na URL **"/web/login"**.
EX: https://webapp-movesync.azurewebsites.net/web/login

Os usuários de teste são **"admin"** (acesso total) e **"operador"** (leituras, simulação e ajustes), com as senhas definidas em `ADMIN_PASSWORD` e `OPERADOR_PASSWORD`.
