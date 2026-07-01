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
RUN set -eux; \
    actual_commit="$(git rev-parse HEAD)"; \
    actual_tag="$(git describe --tags --exact-match 2>/dev/null || true)"; \
    printf '{\n  "source": "build",\n  "repo": "%s",\n  "ref": "%s",\n  "commit": "%s",\n  "tag": "%s",\n  "version": "%s",\n  "buildDate": "%s"\n}\n' \
      "${CLIPROXYAPI_REPO}" "${CLIPROXYAPI_REF}" "${actual_commit}" "${actual_tag}" "${VERSION}" "${BUILD_DATE}" \
      > /out/cliproxyapi-version.json

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

FROM alpine:3.21 AS cpa-usage-keeper-source

ARG CPA_USAGE_KEEPER_REPO=https://github.com/Willxup/cpa-usage-keeper.git
ARG CPA_USAGE_KEEPER_REF=main

RUN apk add --no-cache ca-certificates git

WORKDIR /src
RUN git clone --depth 1 --branch "${CPA_USAGE_KEEPER_REF}" "${CPA_USAGE_KEEPER_REPO}" /src

FROM node:22-alpine AS cpa-usage-keeper-web-builder

WORKDIR /app/web
COPY --from=cpa-usage-keeper-source /src/web/package.json /src/web/package-lock.json ./
RUN npm ci
COPY --from=cpa-usage-keeper-source /src/web ./
RUN npm run build

FROM golang:1.26-alpine AS cpa-usage-keeper-builder

ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG CPA_USAGE_KEEPER_VERSION=dev

WORKDIR /src
RUN apk add --no-cache build-base
COPY --from=cpa-usage-keeper-source /src/go.mod /src/go.sum ./
RUN go mod download
COPY --from=cpa-usage-keeper-source /src/cmd ./cmd
COPY --from=cpa-usage-keeper-source /src/internal ./internal
RUN mkdir -p ./web
COPY --from=cpa-usage-keeper-source /src/web/static.go ./web/static.go
COPY --from=cpa-usage-keeper-web-builder /app/web/dist ./web/dist
RUN CGO_ENABLED=1 GOOS="${TARGETOS:-linux}" GOARCH="${TARGETARCH:-amd64}" \
    go build \
      -ldflags="-s -w -linkmode external -extldflags=-static -X cpa-usage-keeper/internal/version.Version=${CPA_USAGE_KEEPER_VERSION}" \
      -o /out/cpa-usage-keeper \
      ./cmd/server/main.go

FROM ubuntu:24.04

ARG APT_MIRROR=http://azure.archive.ubuntu.com/ubuntu
ARG PIP_INDEX_URL=https://pypi.org/simple/
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
COPY --from=cliproxy-builder /out/cliproxyapi-version.json /CLIProxyAPI/version.json
COPY --from=cpa-manager-plus-builder /out/cpa-manager-plus /usr/local/bin/cpa-manager-plus
COPY --from=cpa-manager-plus-builder /out/management.html /CLIProxyAPI/management.html
COPY --from=cpa-usage-keeper-builder /out/cpa-usage-keeper /usr/local/bin/cpa-usage-keeper

RUN mkdir -p \
      /CLIProxyAPI/backups \
      /CLIProxyAPI/logs \
      /CLIProxyAPI/static \
      /data \
      /home/user/cpa-manager-plus-backups \
      /home/user/cpa-usage-keeper-data \
      /home/user/.cli-proxy-api \
      /home/user/.sync-backup \
 && chmod +x /CLIProxyAPI/CLIProxyAPI /usr/local/bin/cpa-manager-plus /usr/local/bin/cpa-usage-keeper

RUN mkdir -p /home/user/logs && chown -R 1000:1000 /home/user/logs
COPY --chown=1000:1000 supervisor/supervisord.conf /home/user/supervisord.conf

COPY --chown=1000:1000 sync /home/user/sync
RUN chown -R 1000:1000 /home/user/sync

RUN mkdir -p /home/user/scripts && chown -R 1000:1000 /home/user/scripts
COPY --chown=1000:1000 scripts/run-cliproxyapi.sh /home/user/scripts/run-cliproxyapi.sh
COPY --chown=1000:1000 scripts/run-cpa-manager-plus.sh /home/user/scripts/run-cpa-manager-plus.sh
COPY --chown=1000:1000 scripts/run-cpa-usage-keeper.sh /home/user/scripts/run-cpa-usage-keeper.sh
COPY --chown=1000:1000 scripts/run-syncd.sh /home/user/scripts/run-syncd.sh
COPY --chown=1000:1000 scripts/wait-for-sync.sh /home/user/scripts/wait-for-sync.sh
COPY --chown=1000:1000 scripts/update-cliproxyapi.sh /home/user/scripts/update-cliproxyapi.sh
RUN sed -i 's/\r$//' /home/user/scripts/*.sh && \
    chmod +x /home/user/scripts/*.sh

ENV GITHUB_REPO="" \
    GITHUB_PAT="" \
    CLIPROXYAPI_REPO="https://github.com/router-for-me/CLIProxyAPI" \
    CLIPROXY_UPDATE_TOKEN="" \
    GIT_BRANCH="main" \
    HIST_DIR="/home/user/.sync-backup" \
    SYNC_INTERVAL=300 \
    SYNC_WAIT_TIMEOUT=1800 \
    SYNC_PORT=5321 \
    SYNC_TARGETS="home/user/.cli-proxy-api/ CLIProxyAPI/config.yaml data/ home/user/cpa-usage-keeper-data/" \
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
    CPA_USAGE_KEEPER_ENABLED="auto" \
    CPA_USAGE_KEEPER_APP_PORT="8080" \
    CPA_USAGE_KEEPER_APP_BASE_PATH="/t" \
    CPA_USAGE_KEEPER_WORK_DIR="/home/user/cpa-usage-keeper-data" \
    CPA_USAGE_KEEPER_AUTH_ENABLED="false" \
    DEPLOY=""

EXPOSE 8317 8085 1455 54545 51121 11451 5321 18080 18317 8080

CMD ["supervisord", "-c", "/home/user/supervisord.conf"]
