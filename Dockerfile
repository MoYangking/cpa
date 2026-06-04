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

FROM ubuntu:24.04

ARG APT_MIRROR=http://azure.archive.ubuntu.com/ubuntu
ARG PIP_INDEX_URL=https://pypi.org/simple/

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
    FILEBROWSER_URL="$(curl -fsSL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | \
      jq -r '.assets[] | select(.name | contains("linux-amd64-filebrowser.tar.gz")) | .browser_download_url' | \
      head -n 1 | tr -d '\r')"; \
    test -n "${FILEBROWSER_URL}"; \
    curl -fL -o /tmp/filebrowser.tar.gz "${FILEBROWSER_URL}"; \
    tar -xzf /tmp/filebrowser.tar.gz -C /tmp; \
    mv /tmp/filebrowser /home/user/filebrowser; \
    chmod +x /home/user/filebrowser; \
    chown 1000:1000 /home/user/filebrowser; \
    rm -f /tmp/filebrowser.tar.gz; \
    mkdir -p /home/user/filebrowser-data; \
    chown -R 1000:1000 /home/user/filebrowser-data

RUN set -eux; \
    GOTTY_URL="$(curl -fsSL https://api.github.com/repos/sorenisanerd/gotty/releases/latest | \
      jq -r '.assets[] | select(.name | test("gotty_v.*_linux_amd64\\.tar\\.gz$")) | .browser_download_url' | \
      head -n 1 | tr -d '\r')"; \
    test -n "${GOTTY_URL}"; \
    curl -fL -o /tmp/gotty.tar.gz "${GOTTY_URL}"; \
    tar -xzf /tmp/gotty.tar.gz -C /tmp; \
    mv /tmp/gotty /home/user/gotty; \
    chmod +x /home/user/gotty; \
    chown 1000:1000 /home/user/gotty; \
    rm -f /tmp/gotty.tar.gz

COPY --from=cliproxy-builder /out/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI
COPY --from=cliproxy-builder /out/config.example.yaml /CLIProxyAPI/config.example.yaml

RUN mkdir -p \
      /CLIProxyAPI/backups \
      /CLIProxyAPI/logs \
      /CLIProxyAPI/static \
      /home/user/.cli-proxy-api \
      /home/user/.sync-backup \
 && chmod +x /CLIProxyAPI/CLIProxyAPI

RUN mkdir -p /home/user/logs && chown -R 1000:1000 /home/user/logs
COPY --chown=1000:1000 supervisor/supervisord.conf /home/user/supervisord.conf

COPY --chown=1000:1000 sync /home/user/sync
RUN chown -R 1000:1000 /home/user/sync

RUN mkdir -p /home/user/scripts && chown -R 1000:1000 /home/user/scripts
COPY --chown=1000:1000 scripts/run-cliproxyapi.sh /home/user/scripts/run-cliproxyapi.sh
COPY --chown=1000:1000 scripts/run-syncd.sh /home/user/scripts/run-syncd.sh
COPY --chown=1000:1000 scripts/wait-for-sync.sh /home/user/scripts/wait-for-sync.sh
RUN sed -i 's/\r$//' /home/user/scripts/*.sh && \
    chmod +x /home/user/scripts/*.sh

ENV GITHUB_REPO="" \
    GITHUB_PAT="" \
    GIT_BRANCH="main" \
    HIST_DIR="/home/user/.sync-backup" \
    SYNC_INTERVAL=180 \
    SYNC_WAIT_TIMEOUT=1800 \
    SYNC_PORT=5321 \
    SYNC_TARGETS="home/user/.cli-proxy-api/ CLIProxyAPI/config.yaml home/user/filebrowser-data/filebrowser.db" \
    CLI_PROXY_API_CONFIG_FILE="/CLIProxyAPI/config.yaml" \
    CLI_PROXY_API_INTERNAL_BASE="http://127.0.0.1:8317" \
    DEPLOY=""

EXPOSE 8317 8085 1455 54545 51121 11451 5321 8888 18080

CMD ["supervisord", "-c", "/home/user/supervisord.conf"]
