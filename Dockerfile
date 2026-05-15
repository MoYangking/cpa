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
    TZ=Asia/Shanghai \
    VIRTUAL_ENV=/root/.venv \
    PATH=/root/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    mirror="${APT_MIRROR%/}"; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|${mirror}|g; s|http://security.ubuntu.com/ubuntu|${mirror}|g" /etc/apt/sources.list.d/ubuntu.sources; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    nginx-full \
    python3 \
    python3-pip \
    python3-venv \
    rsync \
    supervisor \
    tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /CLIProxyAPI

RUN python3 -m venv "$VIRTUAL_ENV" && \
    "$VIRTUAL_ENV/bin/pip" install --no-cache-dir --upgrade pip && \
    "$VIRTUAL_ENV/bin/pip" install --no-cache-dir --index-url "${PIP_INDEX_URL}" fastapi uvicorn httpx

COPY --from=cliproxy-builder /out/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI
COPY --from=cliproxy-builder /out/config.example.yaml /CLIProxyAPI/config.example.yaml

RUN mkdir -p \
      /CLIProxyAPI/backups \
      /CLIProxyAPI/logs \
      /home/user \
      /home/user/.sync-backup \
      /home/user/scripts \
      /root/.cli-proxy-api \
 && chmod +x /CLIProxyAPI/CLIProxyAPI

COPY supervisor/supervisord.conf /home/user/supervisord.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY sync /home/user/sync
COPY scripts/run-syncd.sh /home/user/scripts/run-syncd.sh
COPY scripts/run-cliproxyapi.sh /home/user/scripts/run-cliproxyapi.sh
COPY scripts/wait-for-sync.sh /home/user/scripts/wait-for-sync.sh

RUN sed -i 's/\r$//' /home/user/scripts/*.sh && \
    chmod +x /home/user/scripts/*.sh

EXPOSE 7860 8317 8085 1455 54545 51121 11451 5321

CMD ["supervisord", "-c", "/home/user/supervisord.conf"]
