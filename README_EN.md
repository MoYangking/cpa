# CLIProxyAPI + Sync Container

This repository used to package `NapCat + MaiBot + Sync` in a single container. It has now been refactored to use [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) instead, and the old `maibot`, `maim-bot-adapters`, `sin-proxy`, `napcat`, and `xvfb` stack has been removed.

## What this repo does now

This is a container wrapper around CLIProxyAPI with three responsibilities:

- run `CLIProxyAPI`
- expose a single `7860` entrypoint with `nginx`
- optionally persist key data through the existing GitHub-backed `sync` service

It is not the upstream CLIProxyAPI source repository. The image clones and builds upstream CLIProxyAPI during Docker build time.

## Preserved paths

The default persisted targets are now:

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`

Before CLIProxyAPI starts, the container backs up any existing contents from those paths into `/CLIProxyAPI/backups/<timestamp>/`.

## Ports

- `7860`: unified entrypoint; `/sync/` goes to the sync UI, everything else goes to CLIProxyAPI
- `8317`: direct CLIProxyAPI port
- `5321`: direct sync service port

For OAuth callback compatibility with upstream CLIProxyAPI, the image also exposes:

- `8085`
- `1455`
- `54545`
- `51121`
- `11451`

## Sync behavior

Sync is optional now:

- if `GITHUB_REPO` and `GITHUB_PAT` are set, the container waits for the first sync before starting CLIProxyAPI
- if they are not set, sync is skipped and CLIProxyAPI starts immediately

## Environment variables

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `GITHUB_REPO` | No | empty | Persistence repo in `owner/repo` format |
| `GITHUB_PAT` | No | empty | GitHub token |
| `GIT_BRANCH` | No | `main` | Sync branch |
| `HIST_DIR` | No | `/home/user/.sync-backup` | Local sync checkout path |
| `SYNC_INTERVAL` | No | `180` | Periodic sync interval in seconds |
| `SYNC_WAIT_TIMEOUT` | No | `1800` | Max wait time before service startup; set `0` to disable waiting |
| `TZ` | No | `Asia/Shanghai` | Container timezone |
| `DEPLOY` | No | empty | Set to `cloud` when you want CLIProxyAPI cloud deploy behavior |

If `/CLIProxyAPI/config.yaml` is missing or empty, the startup script seeds it from upstream `config.example.yaml`.

## Local Docker

```bash
docker build -t cliproxyapi-sync:latest .
docker run -d \
  -p 7860:7860 \
  -p 8317:8317 \
  -p 8085:8085 \
  -p 1455:1455 \
  -p 54545:54545 \
  -p 51121:51121 \
  -p 11451:11451 \
  --name cliproxyapi \
  cliproxyapi-sync:latest
```

Add `GITHUB_REPO` and `GITHUB_PAT` only if you want GitHub-backed persistence.
