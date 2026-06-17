#!/usr/bin/env bash

set -euo pipefail

APP_BIN="/usr/local/bin/cpa-manager-plus"
DATA_DIR="${USAGE_DATA_DIR:-/data}"
DB_PATH="${USAGE_DB_PATH:-${DATA_DIR%/}/usage.sqlite}"
DATA_KEY_PATH="${CPA_MANAGER_DATA_KEY_PATH:-${DATA_DIR%/}/data.key}"
BACKUP_ROOT="${CPA_MANAGER_PLUS_BACKUP_ROOT:-/home/user/cpa-manager-plus-backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

had_data=0
if [[ -d "${DATA_DIR}" ]] && find -L "${DATA_DIR}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  had_data=1
fi

mkdir -p \
  "${DATA_DIR}" \
  "$(dirname "${DB_PATH}")" \
  "$(dirname "${DATA_KEY_PATH}")" \
  "${BACKUP_ROOT}"

if [[ ${had_data} -eq 1 ]]; then
  mkdir -p "${BACKUP_DIR}"
  cp -aL "${DATA_DIR}" "${BACKUP_DIR}/data"
  echo "[cpa-manager-plus] Backed up ${DATA_DIR} to ${BACKUP_DIR}/data"
fi

echo "[cpa-manager-plus] Starting Manager Server on ${HTTP_ADDR:-0.0.0.0:18317}"
exec "${APP_BIN}"
