#!/usr/bin/env bash
set -euo pipefail

SYNC_COMPLETE="/home/user/.sync-backup/.sync-complete"
SYNC_PROGRESS="/home/user/.sync-backup/.sync-progress.json"
MAX_WAIT="${SYNC_WAIT_TIMEOUT:-1800}"
ELAPSED=0
CHECK_INTERVAL=5

read_progress() {
  STAGE=""
  PROGRESS=""
  CURRENT=""
  TOTAL=""

  if [[ ! -f "${SYNC_PROGRESS}" ]]; then
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    STAGE="$(jq -r '.stage // empty' "${SYNC_PROGRESS}" 2>/dev/null || true)"
    PROGRESS="$(jq -r '.progress // empty' "${SYNC_PROGRESS}" 2>/dev/null || true)"
    CURRENT="$(jq -r '.current // empty' "${SYNC_PROGRESS}" 2>/dev/null || true)"
    TOTAL="$(jq -r '.total // empty' "${SYNC_PROGRESS}" 2>/dev/null || true)"
    return 0
  fi

  STAGE="$(grep -oE '"stage"[[:space:]]*:[[:space:]]*"[^"]*"' "${SYNC_PROGRESS}" 2>/dev/null | head -n1 | sed -E 's/.*"([^"]*)".*/\1/' || true)"
  PROGRESS="$(grep -oE '"progress"[[:space:]]*:[[:space:]]*[0-9]+' "${SYNC_PROGRESS}" 2>/dev/null | head -n1 | grep -oE '[0-9]+' || true)"
  CURRENT="$(grep -oE '"current"[[:space:]]*:[[:space:]]*[0-9]+' "${SYNC_PROGRESS}" 2>/dev/null | head -n1 | grep -oE '[0-9]+' || true)"
  TOTAL="$(grep -oE '"total"[[:space:]]*:[[:space:]]*[0-9]+' "${SYNC_PROGRESS}" 2>/dev/null | head -n1 | grep -oE '[0-9]+' || true)"
  return 0
}

if [[ -z "${GITHUB_REPO:-}" || -z "${GITHUB_PAT:-}" ]]; then
  echo "[wait-for-sync] GitHub sync disabled, continuing without waiting."
  exit 0
fi

if [[ "${MAX_WAIT}" == "0" ]]; then
  echo "[wait-for-sync] SYNC_WAIT_TIMEOUT=0, continuing without waiting."
  exit 0
fi

echo "[wait-for-sync] Waiting for sync to complete..."
echo "[wait-for-sync] Timeout: ${MAX_WAIT} seconds"

while [[ "${ELAPSED}" -lt "${MAX_WAIT}" ]]; do
  if [[ -f "${SYNC_COMPLETE}" ]]; then
    file_age="$(($(date +%s) - $(stat -c %Y "${SYNC_COMPLETE}" 2>/dev/null || echo 0)))"
    if [[ "${file_age}" -lt 600 ]]; then
      echo "[wait-for-sync] Sync completed. Starting service..."
      exit 0
    fi
    echo "[wait-for-sync] Sync marker is stale (${file_age}s), waiting for a fresh sync..."
  fi

  if [[ -f "${SYNC_PROGRESS}" ]]; then
    read_progress || true
    if [[ -n "${PROGRESS}" ]]; then
      if [[ -n "${CURRENT}" && -n "${TOTAL}" && "${TOTAL}" =~ ^[0-9]+$ && "${TOTAL}" -gt 0 ]]; then
        echo "[wait-for-sync] Progress: ${PROGRESS}% (Stage: ${STAGE}, ${CURRENT}/${TOTAL} files)"
      else
        echo "[wait-for-sync] Progress: ${PROGRESS}% (Stage: ${STAGE})"
      fi
    else
      echo "[wait-for-sync] Waiting... (${ELAPSED}s elapsed)"
    fi
  else
    echo "[wait-for-sync] Waiting for sync to start... (${ELAPSED}s elapsed)"
  fi

  sleep "${CHECK_INTERVAL}"
  ELAPSED=$((ELAPSED + CHECK_INTERVAL))
done

echo "[wait-for-sync] Timeout after ${MAX_WAIT} seconds"
echo "[wait-for-sync] Starting service anyway to avoid permanent block..."
echo "[wait-for-sync] Note: Some data may not be fully synced!"
exit 0
