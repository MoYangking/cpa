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
ADMIN_CONFIG_FILE="${ADMIN_CONFIG_FILE:-/home/user/nginx/admin_config.json}"
TARGET_BACKEND="${CLI_PROXY_API_INTERNAL_BASE:-http://127.0.0.1:8317}"
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

if [[ -f "${ADMIN_CONFIG_FILE}" ]] && command -v jq >/dev/null 2>&1; then
  tmp_file="$(mktemp)"
  if jq --arg backend "${TARGET_BACKEND}" '
      .default_backend =
        (if (.default_backend // "") == "" or .default_backend == "http://127.0.0.1:8001"
         then $backend
         else .default_backend
         end)
    ' "${ADMIN_CONFIG_FILE}" > "${tmp_file}"; then
    mv "${tmp_file}" "${ADMIN_CONFIG_FILE}"
    echo "[cli-proxy-api] Ensured default backend in ${ADMIN_CONFIG_FILE} is ${TARGET_BACKEND}"
  else
    rm -f "${tmp_file}"
    echo "[cli-proxy-api] WARN: failed to update ${ADMIN_CONFIG_FILE}" >&2
  fi
fi

cd "${APP_DIR}"
exec "${APP_BIN}"
