FROM golang:1.26-alpine AS cliproxy-builder

ARG CLIPROXYAPI_REPO=https://github.com/router-for-me/CLIProxyAPI.git
ARG CLIPROXYAPI_REF=main
ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN apk add --no-cache git

WORKDIR /src
RUN git clone --depth 1 --branch "${CLIPROXYAPI_REF}" "${CLIPROXYAPI_REPO}" /src
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" \
    -o /out/CLIProxyAPI \
    ./cmd/server/
RUN cp /src/config.example.yaml /out/config.example.yaml

FROM alpine:3.21 AS cpa-manager-plus-source

ARG CPA_MANAGER_PLUS_REPO=https://github.com/seakee/CPA-Manager-Plus.git
ARG CPA_MANAGER_PLUS_REF=main

RUN apk add --no-cache ca-certificates git

WORKDIR /src
RUN git clone --depth 1 --branch "${CPA_MANAGER_PLUS_REF}" "${CPA_MANAGER_PLUS_REPO}" /src

FROM node:22-alpine AS cpa-manager-plus-web-builder

ARG CPA_MANAGER_PLUS_VERSION=dev
ARG VITE_DEFAULT_CPA_BASE_URL=http://127.0.0.1:8317

WORKDIR /app
COPY --from=cpa-manager-plus-source /src/package*.json ./
COPY --from=cpa-manager-plus-source /src/apps/web/package.json ./apps/web/package.json
RUN npm ci
COPY --from=cpa-manager-plus-source /src/apps/web ./apps/web
WORKDIR /app/apps/web
RUN VERSION="${CPA_MANAGER_PLUS_VERSION}" \
    VITE_DEFAULT_CPA_BASE_URL="${VITE_DEFAULT_CPA_BASE_URL}" \
    npm run build

FROM golang:1.24-alpine AS cpa-manager-plus-builder

ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src
COPY --from=cpa-manager-plus-source /src/apps/manager-server ./apps/manager-server
COPY --from=cpa-manager-plus-web-builder /app/apps/web/dist/index.html ./apps/manager-server/internal/httpapi/web/management.html
WORKDIR /src/apps/manager-server
RUN go mod download
RUN CGO_ENABLED=0 GOOS="${TARGETOS:-linux}" GOARCH="${TARGETARCH:-amd64}" \
    go build -o /out/cpa-manager-plus ./cmd/cpa-manager-plus
RUN cp /src/apps/manager-server/internal/httpapi/web/management.html /out/management.html

FROM ubuntu:24.04

ARG APT_MIRROR=http://azure.archive.ubuntu.com/ubuntu
ARG PIP_INDEX_URL=https://pypi.org/simple/
ARG FILEBROWSER_URL=https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz
ARG GOTTY_VERSION=v1.8.0
ARG GOTTY_URL=

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

RUN set -eux; \
    mirror="${APT_MIRROR%/}"; \
    if [ -f /etc/apt/sources.list ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|${mirror}|g; s|http://security.ubuntu.com/ubuntu|${mirror}|g" /etc/apt/sources.list; \
    fi; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|${mirror}|g; s|http://security.ubuntu.com/ubuntu|${mirror}|g" /etc/apt/sources.list.d/ubuntu.sources; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    rsync \
    supervisor \
    tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/user && chown -R 1000:1000 /home/user
ENV HOME=/home/user \
    VIRTUAL_ENV=/home/user/.venv \
    PATH=/home/user/.venv/bin:/home/user/.local/bin:$PATH
WORKDIR /home/user

RUN python3 -m venv "$VIRTUAL_ENV" && \
    "$VIRTUAL_ENV/bin/pip" install --no-cache-dir --upgrade pip uv

RUN uv pip install --no-cache-dir --index-url ${PIP_INDEX_URL} fastapi uvicorn httpx
RUN chown -R 1000:1000 "$VIRTUAL_ENV"

RUN set -eux; \
    url="${FILEBROWSER_URL}"; \
    test -n "${url}"; \
    curl -fL -o /tmp/filebrowser.tar.gz "${url}"; \
    tar -xzf /tmp/filebrowser.tar.gz -C /tmp; \
    mv /tmp/filebrowser /home/user/filebrowser; \
    chmod +x /home/user/filebrowser; \
    chown 1000:1000 /home/user/filebrowser; \
    rm -f /tmp/filebrowser.tar.gz; \
    mkdir -p /home/user/filebrowser-data; \
    chown -R 1000:1000 /home/user/filebrowser-data

RUN set -eux; \
    url="${GOTTY_URL:-https://github.com/sorenisanerd/gotty/releases/download/${GOTTY_VERSION}/gotty_${GOTTY_VERSION}_linux_amd64.tar.gz}"; \
    test -n "${url}"; \
    curl -fL -o /tmp/gotty.tar.gz "${url}"; \
    tar -xzf /tmp/gotty.tar.gz -C /tmp; \
    mv /tmp/gotty /home/user/gotty; \
    chmod +x /home/user/gotty; \
    chown 1000:1000 /home/user/gotty; \
    rm -f /tmp/gotty.tar.gz

COPY --from=cliproxy-builder /out/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI
COPY --from=cliproxy-builder /out/config.example.yaml /CLIProxyAPI/config.example.yaml
COPY --from=cpa-manager-plus-builder /out/cpa-manager-plus /usr/local/bin/cpa-manager-plus
COPY --from=cpa-manager-plus-builder /out/management.html /CLIProxyAPI/management.html

RUN mkdir -p \
      /CLIProxyAPI/backups \
      /CLIProxyAPI/logs \
      /CLIProxyAPI/static \
      /data \
      /home/user/cpa-manager-plus-backups \
      /home/user/.cli-proxy-api \
      /home/user/.sync-backup \
 && chmod +x /CLIProxyAPI/CLIProxyAPI /usr/local/bin/cpa-manager-plus

RUN mkdir -p /home/user/logs && chown -R 1000:1000 /home/user/logs
COPY --chown=1000:1000 supervisor/supervisord.conf /home/user/supervisord.conf

COPY --chown=1000:1000 sync /home/user/sync
RUN chown -R 1000:1000 /home/user/sync

RUN mkdir -p /home/user/scripts && chown -R 1000:1000 /home/user/scripts
COPY --chown=1000:1000 scripts/run-cliproxyapi.sh /home/user/scripts/run-cliproxyapi.sh
COPY --chown=1000:1000 scripts/run-cpa-manager-plus.sh /home/user/scripts/run-cpa-manager-plus.sh
COPY --chown=1000:1000 scripts/run-syncd.sh /home/user/scripts/run-syncd.sh
COPY --chown=1000:1000 scripts/wait-for-sync.sh /home/user/scripts/wait-for-sync.sh
RUN sed -i 's/\r$//' /home/user/scripts/*.sh && \
    chmod +x /home/user/scripts/*.sh

ENV GITHUB_REPO="" \
    GITHUB_PAT="" \
    GIT_BRANCH="main" \
    HIST_DIR="/home/user/.sync-backup" \
    SYNC_INTERVAL=300 \
    SYNC_WAIT_TIMEOUT=1800 \
    SYNC_PORT=5321 \
    SYNC_TARGETS="home/user/.cli-proxy-api/ CLIProxyAPI/config.yaml data/ home/user/filebrowser-data/filebrowser.db" \
    CLI_PROXY_API_CONFIG_FILE="/CLIProxyAPI/config.yaml" \
    CLI_PROXY_API_INTERNAL_BASE="http://127.0.0.1:8317" \
    HTTP_ADDR="0.0.0.0:18317" \
    USAGE_DATA_DIR="/data" \
    USAGE_DB_PATH="/data/usage.sqlite" \
    CPA_MANAGER_DATA_KEY_PATH="/data/data.key" \
    USAGE_COLLECTOR_MODE="auto" \
    USAGE_RESP_QUEUE="usage" \
    USAGE_RESP_POP_SIDE="right" \
    USAGE_BATCH_SIZE="100" \
    USAGE_POLL_INTERVAL_MS="500" \
    USAGE_QUERY_LIMIT="50000" \
    USAGE_CORS_ORIGINS="*" \
    DEPLOY=""

EXPOSE 8317 8085 1455 54545 51121 11451 5321 8888 18080 18317

CMD ["supervisord", "-c", "/home/user/supervisord.conf"]
