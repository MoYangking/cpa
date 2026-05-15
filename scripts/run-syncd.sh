#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${GITHUB_REPO:-}" || -z "${GITHUB_PAT:-}" ]]; then
  echo "[syncd] Remote sync is disabled. Sync web UI will stay available."
fi

exec /home/user/.venv/bin/python -m sync
