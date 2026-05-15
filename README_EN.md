# CLIProxyAPI + Sync Container

This repository used to package `NapCat + MaiBot + Sync` in a single container. It now uses [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) as the core service, removes the old `maibot`, `maim-bot-adapters`, `sin-proxy`, `napcat`, and `xvfb` stack, and keeps `filebrowser` plus `gotty` as operational tools.

## Included services

- `CLIProxyAPI`: OpenAI / Gemini / Claude / Codex compatible proxy
- `sync`: optional GitHub-backed persistence
- `nginx`: unified entrypoint on port `7860`
- `filebrowser`: file manager at `/filebrowser/`
- `gotty`: web terminal at `/t/`

## Backup and persistence paths

Before starting CLIProxyAPI, the container backs up:

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`

Backups are stored under:

- `/CLIProxyAPI/backups/<timestamp>/`

Default sync targets now include:

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`
- `/home/user/filebrowser-data/filebrowser.db`

The `filebrowser` database is included again so its state survives sync-enabled deployments.

## Entry points

- `7860`: unified entrypoint
- `/sync/`: sync UI
- `/filebrowser/`: file manager
- `/t/`: web terminal
- everything else: proxied to `CLIProxyAPI`

Direct CLIProxyAPI and OAuth callback related ports are also kept:

- `8317`
- `8085`
- `1455`
- `54545`
- `51121`
- `11451`

## Environment variables

Sync:

| Name | Default | Description |
| --- | --- | --- |
| `GITHUB_REPO` | empty | Persistence repo in `owner/repo` format |
| `GITHUB_PAT` | empty | GitHub token |
| `GIT_BRANCH` | `main` | Sync branch |
| `HIST_DIR` | `/home/user/.sync-backup` | Local sync checkout path |
| `SYNC_INTERVAL` | `180` | Periodic sync interval in seconds |
| `SYNC_WAIT_TIMEOUT` | `1800` | Max wait before service startup; `0` disables waiting |

CLIProxyAPI:

| Name | Default | Description |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | Container timezone |
| `DEPLOY` | empty | Set to `cloud` for CLIProxyAPI cloud deploy mode |

GoTTY:

| Name | Default | Description |
| --- | --- | --- |
| `GOTTY_USERNAME` | `admin` | Username for `/t/` |
| `GOTTY_PASSWORD` | `adminadminadmin` | Password for `/t/` |

If `/CLIProxyAPI/config.yaml` is missing or empty, startup seeds it from upstream `config.example.yaml`.
