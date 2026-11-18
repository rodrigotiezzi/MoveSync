#!/usr/bin/env bash
# =====================================================================================
# MoveSync - Infraestrutura no Azure (Azure CLI) - rodar no Azure Cloud Shell (Bash)
#
# Antes de rodar, defina as senhas no terminal (elas NÃO ficam no repositório):
#   SQL_ADMIN_PASSWORD="..."  RABBITMQ_PASSWORD="..."  JWT_SECRET="..." (32+ caracteres)
#   Opcional (IA generativa): OPENAI_API_KEY="..." IA_HABILITADA=true
#
#   bash scripts/infra-azure.sh
# =====================================================================================
set -euo pipefail

# Gerais
RESOURCE_GROUP_NAME="rg-movesync"
LOCATION="eastus2"
SQL_LOCATION="centralus"

# Web App
WEBAPP_NAME="webapp-movesync"
APP_SERVICE_PLAN="plan-movesync"
SKU="B1"
RUNTIME="TOMCAT:10.1-java21"

# Banco de Dados (Azure SQL)
SQL_SERVER_NAME="sqlserver-movesync"
SQL_DB_NAME="movesyncdb"
SQL_ADMIN_USER="dbadmin"

# RabbitMQ (Azure Container Instance)
RABBITMQ_ACI_NAME="aci-movesync-rabbitmq"
RABBITMQ_DNS_LABEL="movesync-rabbitmq"
RABBITMQ_USER="movesync"
RABBITMQ_HOST="${RABBITMQ_DNS_LABEL}.${LOCATION}.azurecontainer.io"

: "${SQL_ADMIN_PASSWORD:?Defina SQL_ADMIN_PASSWORD antes de rodar}"
: "${RABBITMQ_PASSWORD:?Defina RABBITMQ_PASSWORD antes de rodar}"
: "${JWT_SECRET:?Defina JWT_SECRET (32+ caracteres) antes de rodar}"
OPENAI_API_KEY="${OPENAI_API_KEY:-sem-chave}"
IA_HABILITADA="${IA_HABILITADA:-false}"

echo "== 1. Resource Group"
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" -o none

echo "== 2. Banco de dados (Azure SQL)"
az sql server create \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$SQL_LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD" -o none

az sql server wait --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" --exists

az sql db create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --server "$SQL_SERVER_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective Basic -o none

az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --server "$SQL_SERVER_NAME" \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255 -o none

echo "== 3. RabbitMQ (Azure Container Instance, plugins management + MQTT)"
az provider register --namespace Microsoft.ContainerInstance --wait
az container create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$RABBITMQ_ACI_NAME" \
  --image rabbitmq:3.13-management \
  --os-type Linux \
  --cpu 1 \
  --memory 1.5 \
  --ports 5672 15672 1883 \
  --ip-address Public \
  --dns-name-label "$RABBITMQ_DNS_LABEL" \
  --location "$LOCATION" \
  --environment-variables RABBITMQ_DEFAULT_USER="$RABBITMQ_USER" \
  --secure-environment-variables RABBITMQ_DEFAULT_PASS="$RABBITMQ_PASSWORD" \
  --command-line "bash -c 'rabbitmq-plugins enable --offline rabbitmq_mqtt rabbitmq_management && docker-entrypoint.sh rabbitmq-server'" \
  -o none

echo "== 4. App Service Plan + Web App (.war no Tomcat 10.1 / Java 21)"
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --sku "$SKU" \
  --is-linux -o none

az webapp create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --plan "$APP_SERVICE_PLAN" \
  --runtime "$RUNTIME" -o none

# Garante o runtime certo mesmo se o Web App já existia com outro (ex.: Tomcat 11)
az webapp config set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --linux-fx-version "TOMCAT|10.1-java21" -o none

az resource update \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --namespace Microsoft.Web \
  --resource-type basicPublishingCredentialsPolicies \
  --name scm \
  --parent "sites/$WEBAPP_NAME" \
  --set properties.allow=true -o none

echo "== 5. Variáveis de ambiente do Web App"
SPRING_DATASOURCE_URL="jdbc:sqlserver://${SQL_SERVER_NAME}.database.windows.net:1433;database=${SQL_DB_NAME};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"

az webapp config appsettings set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --settings \
    SPRING_PROFILES_ACTIVE="azure" \
    SPRING_DATASOURCE_URL="$SPRING_DATASOURCE_URL" \
    SPRING_DATASOURCE_USERNAME="$SQL_ADMIN_USER" \
    SPRING_DATASOURCE_PASSWORD="$SQL_ADMIN_PASSWORD" \
    JWT_SECRET="$JWT_SECRET" \
    RABBITMQ_HOST="$RABBITMQ_HOST" \
    RABBITMQ_PORT="5672" \
    RABBITMQ_USER="$RABBITMQ_USER" \
    RABBITMQ_PASSWORD="$RABBITMQ_PASSWORD" \
    RABBITMQ_VHOST="/" \
    RABBITMQ_SSL="false" \
    IA_HABILITADA="$IA_HABILITADA" \
    OPENAI_API_KEY="$OPENAI_API_KEY" \
  -o none

az webapp log config --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP_NAME" \
  --docker-container-logging filesystem -o none

az webapp restart --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP_NAME"

echo
echo "Pronto!"
echo "  API / Swagger : https://${WEBAPP_NAME}.azurewebsites.net/swagger-ui.html"
echo "  Painel /dev   : https://${WEBAPP_NAME}.azurewebsites.net/dev"
echo "  RabbitMQ      : http://${RABBITMQ_HOST}:15672 (usuário ${RABBITMQ_USER})"
echo "  Banco         : ${SQL_SERVER_NAME}.database.windows.net / ${SQL_DB_NAME}"
