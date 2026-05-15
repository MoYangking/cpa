# CLIProxyAPI + Sync Gateway

这个仓库现在是一个单容器网关，核心用途是把 `CLIProxyAPI`、`sync`、`filebrowser`、`gotty` 和基于 OpenResty 的统一入口打包在一起，便于一键部署和持久化。

当前容器内的主要服务：

- `CLIProxyAPI`：提供 OpenAI / Gemini / Claude / Codex 兼容代理接口
- `sync`：把关键配置和认证文件同步到 GitHub 仓库
- `OpenResty`：统一入口，监听 `7860`
- `filebrowser`：文件管理界面，入口 `/filebrowser/`
- `gotty`：Web 终端，入口 `/t/`
- `/admin/ui/`：OpenResty 路由管理界面

上游项目：

- `CLIProxyAPI`: https://github.com/router-for-me/CLIProxyAPI

## 关键备份与持久化

启动 `CLIProxyAPI` 前会自动备份：

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`

备份位置：

- `/CLIProxyAPI/backups/<timestamp>/`

默认同步目标：

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`
- `/home/user/nginx/admin_config.json`
- `/home/user/filebrowser-data/filebrowser.db`

## 入口

- `7860`：统一入口
- `/sync/`：同步管理页
- `/admin/ui/`：路由管理页
- `/filebrowser/`：文件管理
- `/t/`：Web 终端
- 其余路径：转发到 `CLIProxyAPI`

也保留了 `CLIProxyAPI` 常用直连端口：

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
| `HIST_DIR` | `/home/user/.sync-backup` | 同步仓库在容器内的路径 |
| `SYNC_INTERVAL` | `180` | 周期同步间隔（秒） |
| `SYNC_WAIT_TIMEOUT` | `1800` | 业务服务等待首次同步的最长时间；`0` 表示不等待 |
| `SYNC_TARGETS` | 见上文 | 空格分隔的同步目标列表 |

CLIProxyAPI 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `DEPLOY` | 空 | 传给 `CLIProxyAPI` 的部署模式 |
| `CLI_PROXY_API_CONFIG_FILE` | `/CLIProxyAPI/config.yaml` | sync 调试页读取的配置文件路径 |
| `CLI_PROXY_API_INTERNAL_BASE` | `http://127.0.0.1:8317` | sync 调试页探测的内网地址 |

GoTTY 相关：

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `GOTTY_USERNAME` | `admin` | `/t/` 登录用户名 |
| `GOTTY_PASSWORD` | `adminadminadmin` | `/t/` 登录密码 |

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

如果你不想启用 GitHub 同步，也可以不设置 `GITHUB_REPO` 和 `GITHUB_PAT`。这时 `/sync/` 页面仍可访问，但只提供本地视图和手动操作，不会进行远端同步。
