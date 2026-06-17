# CLIProxyAPI + CPA Manager Plus + Sync Gateway

这个仓库是一个单容器工具集，把 `CLIProxyAPI`、`CPA Manager Plus`、`sync`、`filebrowser` 和 `gotty` 打包在一起，便于一键部署、管理和持久化。

当前容器内的主要服务：

- `CLIProxyAPI`：CPA 本体，提供 OpenAI / Gemini / Claude / Codex 兼容代理接口，默认端口 `8317`
- `CPA Manager Plus`：新版 CPA 管理面板和 Manager Server，默认端口 `18317`
- `sync`：把关键配置、认证文件和 Plus 数据目录同步到 GitHub 仓库，管理页入口 `5321/sync/`
- `filebrowser`：文件管理界面，入口 `8888/filebrowser/`
- `gotty`：Web 终端，入口 `18080/t/`

上游项目：

- `CLIProxyAPI`: https://github.com/router-for-me/CLIProxyAPI
- `CPA Manager Plus`: https://github.com/seakee/CPA-Manager-Plus

## 入口

- `8317`：CLIProxyAPI 主接口
- `8317/management.html`：由 CLIProxyAPI 托管的 CPA Manager Plus 面板，适合纯 CPA 面板模式
- `18317/management.html`：CPA Manager Plus Manager Server 面板，支持 SQLite 统计、监控、模型价格、API Key 别名等 Plus 功能
- `5321/sync/`：同步管理页
- `8888/filebrowser/`：文件管理
- `18080/t/`：Web 终端

`CLIProxyAPI` 其他常用直连端口：

- `8317`
- `8085`
- `1455`
- `54545`
- `51121`
- `11451`

## 为什么仍然需要 CLIProxyAPI

`CPA Manager Plus` 不是 `CLIProxyAPI` 的替代品。它是 CPA 的管理面板和可选的 Manager Server。真正处理模型代理、账号认证、`/v0/management/*` 管理接口和用量队列的是 `CLIProxyAPI`。

因此本镜像会同时启动两者：

- `CLIProxyAPI` 跑在 `127.0.0.1:8317`
- `CPA Manager Plus` 跑在 `0.0.0.0:18317`

首次打开 `18317/management.html` 时，CPA 地址建议填写：

```text
http://127.0.0.1:8317
```

管理员密钥来自 `CPA_MANAGER_ADMIN_KEY`，如果未设置，Plus 会在首次启动日志中输出一次 `cmp_admin_...`。

## 关键备份与持久化

启动 `CLIProxyAPI` 前会自动备份：

- `/home/user/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`

备份位置：

- `/CLIProxyAPI/backups/<timestamp>/`

启动 `CPA Manager Plus` 前会自动备份：

- `/data/`

备份位置：

- `/home/user/cpa-manager-plus-backups/<timestamp>/data/`

默认同步目标：

- `/home/user/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`
- `/data/`
- `/home/user/filebrowser-data/filebrowser.db`

Plus 和旧 CPA-Manager 的备份差异在 `/data/`。灾备时不要只备份单个数据库文件，至少要保留：

- `/data/usage.sqlite`
- `/data/usage.sqlite-wal`
- `/data/usage.sqlite-shm`
- `/data/data.key`

其中 `/data/data.key` 用来解密 SQLite 中保存的 CPA Management Key。丢失 `data.key` 后，已加密的 CPA Management Key 无法恢复，只能重新配置 CPA 连接。

## 环境变量

同步相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `GITHUB_REPO` | 空 | 持久化仓库，格式 `owner/repo` |
| `GITHUB_PAT` | 空 | GitHub Token |
| `GIT_BRANCH` | `main` | 同步分支 |
| `HIST_DIR` | `/home/user/.sync-backup` | 同步仓库在容器内的路径 |
| `SYNC_INTERVAL` | `300` | 周期同步间隔，单位秒 |
| `SYNC_WAIT_TIMEOUT` | `1800` | 业务服务等待首次同步的最长时间；`0` 表示不等待 |
| `SYNC_TARGETS` | 见上文 | 空格分隔的同步目标列表 |

CLIProxyAPI 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `DEPLOY` | 空 | 传给 `CLIProxyAPI` 的部署模式 |
| `CLI_PROXY_API_CONFIG_FILE` | `/CLIProxyAPI/config.yaml` | sync 调试页读取的配置文件路径 |
| `CLI_PROXY_API_INTERNAL_BASE` | `http://127.0.0.1:8317` | sync 调试页探测的内网地址 |

CPA Manager Plus 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `HTTP_ADDR` | `0.0.0.0:18317` | Plus Manager Server 监听地址 |
| `USAGE_DATA_DIR` | `/data` | Plus 数据目录 |
| `USAGE_DB_PATH` | `/data/usage.sqlite` | Plus SQLite 路径 |
| `CPA_MANAGER_DATA_KEY_PATH` | `/data/data.key` | Plus 数据加密密钥路径 |
| `CPA_MANAGER_ADMIN_KEY` | 空 | 可选固定管理员密钥；为空时首次启动自动生成 |
| `CPA_UPSTREAM_URL` | 空 | 可选 CPA 地址，用于无人值守启动 |
| `CPA_MANAGEMENT_KEY` | 空 | 可选 CPA Management Key，用于无人值守启动 |
| `USAGE_COLLECTOR_MODE` | `auto` | 用量采集模式 |
| `USAGE_POLL_INTERVAL_MS` | `500` | 队列空闲轮询间隔 |
| `USAGE_QUERY_LIMIT` | `50000` | 最近事件查询上限 |

GoTTY 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `GOTTY_USERNAME` | `admin` | `18080/t/` 登录用户名 |
| `GOTTY_PASSWORD` | `adminadminadmin` | `18080/t/` 登录密码 |

## 本地使用

```bash
docker build -t cpa-plus-sync:latest .

docker run -d \
  -p 8317:8317 \
  -p 8085:8085 \
  -p 1455:1455 \
  -p 54545:54545 \
  -p 51121:51121 \
  -p 11451:11451 \
  -p 18317:18317 \
  -p 5321:5321 \
  -p 8888:8888 \
  -p 18080:18080 \
  -e GITHUB_REPO="<owner>/<repo>" \
  -e GITHUB_PAT="<token>" \
  --name cpa-plus \
  cpa-plus-sync:latest
```

如果你不想启用 GitHub 同步，也可以不设置 `GITHUB_REPO` 和 `GITHUB_PAT`。这时 `5321/sync/` 页面仍可访问，但只提供本地视图和手动操作，不会进行远端同步。
