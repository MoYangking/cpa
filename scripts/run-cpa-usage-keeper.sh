#!/usr/bin/env bash

set -euo pipefail

APP_BIN="/usr/local/bin/cpa-usage-keeper"
ENABLED="${CPA_USAGE_KEEPER_ENABLED:-auto}"
WORK_DIR="${CPA_USAGE_KEEPER_WORK_DIR:-/home/user/cpa-usage-keeper-data}"
BACKUP_ROOT="${CPA_USAGE_KEEPER_BACKUP_ROOT:-/home/user/cpa-usage-keeper-backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

case "${ENABLED}" in
  false|FALSE|False|0|off|OFF)
    echo "[cpa-usage-keeper] Disabled by CPA_USAGE_KEEPER_ENABLED=${ENABLED}"
    exit 0
    ;;
esac

export APP_PORT="${CPA_USAGE_KEEPER_APP_PORT:-${APP_PORT:-8080}}"
export APP_BASE_PATH="${CPA_USAGE_KEEPER_APP_BASE_PATH:-${APP_BASE_PATH:-/t}}"
export CPA_BASE_URL="${CPA_USAGE_KEEPER_CPA_BASE_URL:-${CPA_BASE_URL:-http://127.0.0.1:8317}}"
export CPA_PUBLIC_URL="${CPA_USAGE_KEEPER_CPA_PUBLIC_URL:-${CPA_PUBLIC_URL:-}}"
export REDIS_QUEUE_ADDR="${CPA_USAGE_KEEPER_REDIS_QUEUE_ADDR:-${REDIS_QUEUE_ADDR:-127.0.0.1:8317}}"
export WORK_DIR

if [[ -n "${CPA_USAGE_KEEPER_AUTH_ENABLED:-}" ]]; then
  export AUTH_ENABLED="${CPA_USAGE_KEEPER_AUTH_ENABLED}"
fi
if [[ -n "${CPA_USAGE_KEEPER_LOGIN_PASSWORD:-}" ]]; then
  export LOGIN_PASSWORD="${CPA_USAGE_KEEPER_LOGIN_PASSWORD}"
fi

if [[ -z "${CPA_MANAGEMENT_KEY:-}" ]]; then
  if [[ "${ENABLED}" == "auto" ]]; then
    echo "[cpa-usage-keeper] CPA_MANAGEMENT_KEY is not set; Keeper is waiting in auto mode."
    echo "[cpa-usage-keeper] Set CPA_MANAGEMENT_KEY and restart the container to enable usage persistence."
    exec tail -f /dev/null
  fi
  echo "[cpa-usage-keeper] CPA_MANAGEMENT_KEY is required when CPA_USAGE_KEEPER_ENABLED=${ENABLED}"
  exit 1
fi

CPA_WAIT_TIMEOUT="${CPA_USAGE_KEEPER_WAIT_TIMEOUT:-120}"
CPA_WAIT_INTERVAL="${CPA_USAGE_KEEPER_WAIT_INTERVAL:-2}"
CPA_WAIT_ELAPSED=0
CPA_STATUS_URL="${CPA_BASE_URL%/}/status"

echo "[cpa-usage-keeper] Waiting for CLIProxyAPI at ${CPA_STATUS_URL}"
while [[ "${CPA_WAIT_ELAPSED}" -lt "${CPA_WAIT_TIMEOUT}" ]]; do
  if curl -fsS --max-time 2 "${CPA_STATUS_URL}" >/dev/null 2>&1; then
    echo "[cpa-usage-keeper] CLIProxyAPI is ready."
    break
  fi

  sleep "${CPA_WAIT_INTERVAL}"
  CPA_WAIT_ELAPSED=$((CPA_WAIT_ELAPSED + CPA_WAIT_INTERVAL))
done

if [[ "${CPA_WAIT_ELAPSED}" -ge "${CPA_WAIT_TIMEOUT}" ]]; then
  echo "[cpa-usage-keeper] Timed out waiting for CLIProxyAPI after ${CPA_WAIT_TIMEOUT}s; starting anyway."
fi

had_data=0
if [[ -d "${WORK_DIR}" ]] && find -L "${WORK_DIR}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  had_data=1
fi

mkdir -p "${WORK_DIR}" "${WORK_DIR}/backups" "${WORK_DIR}/logs" "${BACKUP_ROOT}"

if [[ ${had_data} -eq 1 ]]; then
  mkdir -p "${BACKUP_DIR}"
  cp -aL "${WORK_DIR}" "${BACKUP_DIR}/data"
  echo "[cpa-usage-keeper] Backed up ${WORK_DIR} to ${BACKUP_DIR}/data"
fi

echo "[cpa-usage-keeper] Starting on 0.0.0.0:${APP_PORT}${APP_BASE_PATH}"
exec "${APP_BIN}"
