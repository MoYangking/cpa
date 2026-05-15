#!/usr/bin/env bash

set -euo pipefail

APP_DIR="/CLIProxyAPI"
APP_BIN="${APP_DIR}/CLIProxyAPI"
CONFIG_FILE="${APP_DIR}/config.yaml"
CONFIG_TEMPLATE="${APP_DIR}/config.example.yaml"
MANAGEMENT_BUNDLED_HTML="${APP_DIR}/management.html"
MANAGEMENT_STATIC_DIR="${APP_DIR}/static"
MANAGEMENT_STATIC_HTML="${MANAGEMENT_STATIC_DIR}/management.html"
AUTH_DIR="/root/.cli-proxy-api"
LOG_DIR="${APP_DIR}/logs"
BACKUP_ROOT="${APP_DIR}/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

had_auth=0
had_config=0

if [[ -e "${AUTH_DIR}" ]]; then
  had_auth=1
fi

if [[ -e "${CONFIG_FILE}" ]]; then
  had_config=1
fi

mkdir -p "${AUTH_DIR}" "${LOG_DIR}" "${BACKUP_ROOT}"

if [[ ${had_auth} -eq 1 || ${had_config} -eq 1 ]]; then
  mkdir -p "${BACKUP_DIR}/root" "${BACKUP_DIR}/CLIProxyAPI"
fi

if [[ ${had_auth} -eq 1 ]]; then
  cp -aL "${AUTH_DIR}" "${BACKUP_DIR}/root/.cli-proxy-api"
  echo "[cli-proxy-api] Backed up ${AUTH_DIR} to ${BACKUP_DIR}/root/.cli-proxy-api"
fi

if [[ ${had_config} -eq 1 ]]; then
  cp -aL "${CONFIG_FILE}" "${BACKUP_DIR}/CLIProxyAPI/config.yaml"
  echo "[cli-proxy-api] Backed up ${CONFIG_FILE} to ${BACKUP_DIR}/CLIProxyAPI/config.yaml"
fi

if [[ ! -s "${CONFIG_FILE}" && -f "${CONFIG_TEMPLATE}" ]]; then
  cp "${CONFIG_TEMPLATE}" "${CONFIG_FILE}"
  echo "[cli-proxy-api] Seeded ${CONFIG_FILE} from ${CONFIG_TEMPLATE}"
fi

if [[ -f "${MANAGEMENT_BUNDLED_HTML}" ]]; then
  mkdir -p "${MANAGEMENT_STATIC_DIR}"
  cp -f "${MANAGEMENT_BUNDLED_HTML}" "${MANAGEMENT_STATIC_HTML}"
  echo "[cli-proxy-api] Installed bundled management panel to ${MANAGEMENT_STATIC_HTML}"
fi

cd "${APP_DIR}"
exec "${APP_BIN}"
