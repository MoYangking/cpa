#!/usr/bin/env bash

set -euo pipefail

APP_DIR="${CLI_PROXY_API_APP_DIR:-/CLIProxyAPI}"
APP_BIN="${CLI_PROXY_API_BIN:-${APP_DIR}/CLIProxyAPI}"
VERSION_FILE="${CLI_PROXY_API_VERSION_FILE:-${APP_DIR}/version.json}"
BACKUP_ROOT="${CLI_PROXY_API_BINARY_BACKUP_ROOT:-${APP_DIR}/binary-backups}"
REPO_URL="${CLIPROXYAPI_REPO:-https://github.com/router-for-me/CLIProxyAPI}"
VERSION="${1:-latest}"
VARIANT="${CLIPROXYAPI_RELEASE_VARIANT:-}"
RESTART="${CLIPROXYAPI_RESTART_AFTER_UPDATE:-true}"

repo_base="${REPO_URL%.git}"
if [[ "${repo_base}" == git@github.com:* ]]; then
  repo_base="https://github.com/${repo_base#git@github.com:}"
fi

case "$(uname -m)" in
  x86_64 | amd64) arch="amd64" ;;
  aarch64 | arm64) arch="aarch64" ;;
  *)
    echo "[cliproxy-update] Unsupported architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

resolve_latest_version() {
  local effective_url tag

  if effective_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${repo_base}/releases/latest" 2>/dev/null)"; then
    tag="${effective_url##*/}"
    if [[ "${effective_url}" == *"/releases/tag/"* && "${tag}" == v* ]]; then
      echo "${tag}"
      return 0
    fi
  fi

  git ls-remote --tags --sort='v:refname' "${repo_base}.git" 'refs/tags/v*' \
    | awk -F/ '!/\^\{\}$/ { tag=$NF } END { print tag }'
}

if [[ -z "${VERSION}" || "${VERSION}" == "latest" ]]; then
  VERSION="$(resolve_latest_version)"
fi

if [[ -z "${VERSION}" ]]; then
  echo "[cliproxy-update] Unable to resolve latest version" >&2
  exit 3
fi

tag="${VERSION}"
version_no_v="${VERSION#v}"
if [[ "${tag}" != v* ]]; then
  tag="v${tag}"
fi

asset="CLIProxyAPI_${version_no_v}_linux_${arch}${VARIANT}.tar.gz"
download_url="${repo_base}/releases/download/${tag}/${asset}"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

echo "[cliproxy-update] Downloading ${download_url}"
curl -fL -o "${tmp_dir}/cliproxyapi.tar.gz" "${download_url}"
tar -xzf "${tmp_dir}/cliproxyapi.tar.gz" -C "${tmp_dir}"

candidate=""
for name in cli-proxy-api CLIProxyAPI; do
  if [[ -f "${tmp_dir}/${name}" ]]; then
    candidate="${tmp_dir}/${name}"
    break
  fi
done

if [[ -z "${candidate}" ]]; then
  candidate="$(find "${tmp_dir}" -maxdepth 2 -type f \( -name 'cli-proxy-api' -o -name 'CLIProxyAPI' \) | head -n 1)"
fi

if [[ -z "${candidate}" ]]; then
  echo "[cliproxy-update] CLIProxyAPI binary not found in release archive" >&2
  exit 4
fi

mkdir -p "${APP_DIR}" "${BACKUP_ROOT}"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="${BACKUP_ROOT}/${timestamp}"

if [[ -f "${APP_BIN}" ]]; then
  mkdir -p "${backup_dir}"
  cp -aL "${APP_BIN}" "${backup_dir}/CLIProxyAPI"
  echo "[cliproxy-update] Backed up ${APP_BIN} to ${backup_dir}/CLIProxyAPI"
fi

install -m 0755 "${candidate}" "${APP_BIN}.new"
mv -f "${APP_BIN}.new" "${APP_BIN}"

if [[ -f "${tmp_dir}/config.example.yaml" ]]; then
  cp -f "${tmp_dir}/config.example.yaml" "${APP_DIR}/config.example.yaml"
fi

cat > "${VERSION_FILE}" <<EOF
{
  "source": "release",
  "repo": "${repo_base}",
  "version": "${version_no_v}",
  "tag": "${tag}",
  "asset": "${asset}",
  "downloadUrl": "${download_url}",
  "installedAt": "$(date -Iseconds)"
}
EOF

echo "[cliproxy-update] Installed CLIProxyAPI ${tag}"

if [[ "${RESTART}" == "true" || "${RESTART}" == "1" ]]; then
  if command -v supervisorctl >/dev/null 2>&1; then
    echo "[cliproxy-update] Restarting supervisor program cli-proxy-api"
    supervisorctl -c /home/user/supervisord.conf restart cli-proxy-api
  else
    echo "[cliproxy-update] supervisorctl not found, restart skipped"
  fi
fi
