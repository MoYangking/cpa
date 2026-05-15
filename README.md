<!-- 默认中文文档。English version: README_EN.md -->

# CLIProxyAPI + Sync 持久化容器

这个仓库原来是一个 `NapCat + MaiBot + Sync` 的单容器网关。现在已经改成以 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 为核心，保留原来的 GitHub 同步持久化能力，并删除了 `maibot`、`maim-bot-adapters`、`sin-proxy`、`napcat`、`xvfb` 相关运行栈。

## 这个项目现在有什么用

它提供一个可直接用于本地 Docker 或 Hugging Face Spaces 的单容器方案，容器里只有三块核心能力：

- `CLIProxyAPI`：提供 OpenAI / Gemini / Claude / Codex 兼容的代理接口
- `nginx`：对外统一暴露 `7860`，把 `/sync/` 转给同步管理页，其余请求转给 `CLIProxyAPI`
- `sync`：可选的 GitHub 持久化服务，用来同步关键配置与认证数据

上游项目：

- CLIProxyAPI: https://github.com/router-for-me/CLIProxyAPI

## 已保留和备份的关键路径

默认持久化目标已经改成：

- `/root/.cli-proxy-api/`
- `/CLIProxyAPI/config.yaml`

容器启动 `CLIProxyAPI` 前，会先把这两个路径当前存在的内容备份到 `/CLIProxyAPI/backups/<timestamp>/`，然后再继续启动。

如果配置了 GitHub 同步，这两个路径还会通过 `sync` 自动迁移到同步仓库并建立符号链接。

## 端口与入口

常用入口：

- `7860`：统一入口。`/sync/` 是同步管理页，其余路径转发到 `CLIProxyAPI`
- `8317`：直接访问 `CLIProxyAPI`
- `5321`：直接访问 `sync` 管理服务

为了兼容 `CLIProxyAPI` 的 OAuth 回调场景，镜像也暴露了这些上游默认端口：

- `8085`
- `1455`
- `54545`
- `51121`
- `11451`

## Sync 持久化

`sync` 现在是可选的：

- 如果设置了 `GITHUB_REPO` 和 `GITHUB_PAT`，容器会先完成同步，再启动 `CLIProxyAPI`
- 如果没有设置，`sync` 会自动跳过，`CLIProxyAPI` 直接启动

相关环境变量：

| 名称 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `GITHUB_REPO` | 否 | 空 | 持久化仓库，格式 `owner/repo` |
| `GITHUB_PAT` | 否 | 空 | GitHub Token |
| `GIT_BRANCH` | 否 | `main` | 同步分支 |
| `HIST_DIR` | 否 | `/home/user/.sync-backup` | 同步仓库本地目录 |
| `SYNC_INTERVAL` | 否 | `180` | 周期同步间隔（秒） |
| `SYNC_WAIT_TIMEOUT` | 否 | `1800` | 业务服务等待首次同步的最长时间；设为 `0` 表示不等待 |
| `SYNC_TARGETS` | 否 | 见 `sync/core/config.py` | 自定义同步目标 |
| `EXCLUDE_PATHS` | 否 | 空 | 自定义排除路径 |

## CLIProxyAPI 相关环境变量

| 名称 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `TZ` | 否 | `Asia/Shanghai` | 容器时区 |
| `DEPLOY` | 否 | 空 | 需要云部署兼容模式时可设为 `cloud` |

`/CLIProxyAPI/config.yaml` 不存在或为空时，启动脚本会自动用上游 `config.example.yaml` 生成一份初始配置。

## 本地使用

构建镜像：

```bash
docker build -t cliproxyapi-sync:latest .
```

启动容器：

```bash
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

如果你只想本地跑，不需要 GitHub 持久化，可以去掉 `GITHUB_REPO` 和 `GITHUB_PAT`。

## Hugging Face Spaces

如果继续部署到 Hugging Face Spaces，直接访问 Space URL 即可，对外主入口仍然是 `7860`。

- `/sync/`：同步管理页
- `/`、`/v1/...`、`/v0/management/...` 等：转发给 `CLIProxyAPI`

## 说明

这个仓库现在不是 CLIProxyAPI 的源码仓库，而是一个围绕 CLIProxyAPI 的容器封装：

- 负责拉取并编译上游 CLIProxyAPI
- 负责在单容器里编排 `nginx + sync + CLIProxyAPI`
- 负责对 `/root/.cli-proxy-api` 和 `/CLIProxyAPI/config.yaml` 做启动前备份与可选 GitHub 持久化
