#!/usr/bin/env bash
# ==============================================================================
# GEPER - Activar o desactivar temporalmente ENABLE_VULNERABILITY_LABS en localhost
# Uso: sudo ./set-lab-mode-geper.sh true|false
# ==============================================================================
set -euo pipefail

VAL="${1:-false}"
if [ "$VAL" != "true" ] && [ "$VAL" != "false" ]; then
  echo "Uso: $0 true|false" >&2
  exit 1
fi

APP_ENV_FILE="/etc/geper/geper.env"
sed -i "s/^ENABLE_VULNERABILITY_LABS=.*/ENABLE_VULNERABILITY_LABS=${VAL}/" "$APP_ENV_FILE"
systemctl restart geper.service

for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "==> ENABLE_VULNERABILITY_LABS=${VAL} aplicado y servicio geper.service reiniciado."
