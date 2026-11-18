# ☁️ Deploy na Azure — MoveSync

## 📌 Descrição da Solução

A ideia principal do **MoveSync** é um sistema de **semáforos inteligentes com IoT**: sensores e câmeras instalados nos cruzamentos leem o fluxo de veículos e pedestres e o sistema **ajusta o tempo de verde** de cada semáforo conforme o trânsito real — fazendo com que o cidadão passe menos tempo parado no semáforo.

Para sustentar essa proposta, foi desenvolvida uma **API RESTful em Java com Spring Boot**, com persistência em **Azure SQL Database**, que funciona como o back-end de gestão da solução: centraliza o cadastro de **cruzamentos**, **semáforos** e **dispositivos IoT** (câmeras e sensores), vincula os dispositivos a cada semáforo, registra as **leituras de tráfego** (quantidade de veículos, pedestres e velocidade média) e calcula os **ajustes de tempo** — guardando o histórico de cada ajuste (tempo anterior, tempo novo, média de veículos e motivo).

A regra do ajuste usa a média das 5 últimas leituras do semáforo: **verde = 15 s + 1,5 s por veículo**, sempre entre **15 s e 90 s**.

> ⚠️ **Os dados de IoT são fictícios.** Não há hardware real: as leituras são geradas pelo **simulador** (`POST /leitura/simular` ou botão *Simular leituras* no painel) e pelos dados de exemplo do `scripts/script-bd.sql`.

A solução expõe endpoints REST documentados via **Swagger/OpenAPI**, com suporte a busca por parâmetros, paginação e ordenação de resultados, validação de dados de entrada e tratamento global de exceções — cobrindo todo o fluxo, do cadastro do cruzamento até o ajuste automático do semáforo.

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
SQL_ADMIN_USER="dbadmin"
SQL_ADMIN_PASSWORD=""

# Usuários da aplicação
ADMIN_USERNAME="admin"
ADMIN_PASSWORD=""
OPERADOR_USERNAME="operador"
OPERADOR_PASSWORD=""
JWT_SECRET=""
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
