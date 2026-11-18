#!/usr/bin/env bash
# MoveSync - Remove todos os recursos do Azure (usar depois da apresentação)
set -euo pipefail
az group delete --name rg-movesync --yes --no-wait
echo "Exclusão do rg-movesync solicitada (leva alguns minutos)."
