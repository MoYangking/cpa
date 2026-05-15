<!-- 默认中文文档。English version: README_EN.md -->

# CLIProxyAPI + Sync 持久化容器

这个仓库原来是一个 `NapCat + MaiBot + Sync` 的单容器网关。现在已经改成以 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 为核心，删除了 `maibot`、`maim-bot-adapters`、`sin-proxy`、`napcat`、`xvfb` 相关运行栈，同时保留了 `filebrowser` 和 `gotty` 作为运维工具。

## 现在包含哪些服务

- `CLIProxyAPI`：提供 OpenAI / Gemini / Claude / Codex 兼容代理
- `sync`：可选的 GitHub 持久化服务
- `nginx`：统一入口，监听 `7860`
- `filebrowser`：文件管理界面，入口 `/filebrowser/`
- `gotty`：Web 终端，入口 `/t/`

上游项目：

- CLIProxyAPI: https://github.com/router-for-me/CLIProxyAPI

## 关键备份与持久化路径

启动 `CLIProxyAPI` 前会先备份这两个路径：

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`

备份位置：

- `/CLIProxyAPI/backups/<timestamp>/`

默认同步目标现在包括：

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`
- `/home/user/filebrowser-data/filebrowser.db`

其中 `filebrowser` 的数据库被重新纳入同步，方便保留登录状态和配置。

如果仓库根目录存在 `management.html`，镜像会把它打包进去，并在容器启动时安装到 `/CLIProxyAPI/static/management.html`，优先使用这份本地管理面板，不再依赖首次在线下载。

## 入口

- `7860`：统一入口
- `/sync/`：同步管理页
- `/filebrowser/`：文件管理
- `/t/`：Web 终端
- 其余路径：转发到 `CLIProxyAPI`

也保留了 `CLIProxyAPI` 的直接端口和 OAuth 回调端口：

- `8317`
- `8085`
- `1455`
- `54545`
- `51121`
- `11451`

## 环境变量

同步相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `GITHUB_REPO` | 空 | 持久化仓库，格式 `owner/repo` |
| `GITHUB_PAT` | 空 | GitHub Token |
| `GIT_BRANCH` | `main` | 同步分支 |
| `HIST_DIR` | `/home/user/.sync-backup` | 同步仓库本地目录 |
| `SYNC_INTERVAL` | `180` | 周期同步间隔（秒） |
| `SYNC_WAIT_TIMEOUT` | `1800` | 业务服务等待首次同步的最长时间；`0` 表示不等待 |

CLIProxyAPI 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `DEPLOY` | 空 | 设为 `cloud` 时启用 CLIProxyAPI 云部署模式 |

GoTTY 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `GOTTY_USERNAME` | `admin` | `/t/` 登录用户名 |
| `GOTTY_PASSWORD` | `adminadminadmin` | `/t/` 登录密码 |

如果 `/CLIProxyAPI/config.yaml` 不存在或为空，启动脚本会自动用上游 `config.example.yaml` 生成初始配置。

## 本地使用

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
  -e GITHUB_REPO="<owner>/<repo>" \
  -e GITHUB_PAT="<token>" \
  --name cliproxyapi \
  cliproxyapi-sync:latest
```

如果你只想本地运行，可以不设置 `GITHUB_REPO` 和 `GITHUB_PAT`。这时 `sync` 页面仍然可访问，但远程同步会被禁用。
