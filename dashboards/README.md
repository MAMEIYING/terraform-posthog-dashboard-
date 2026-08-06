# Dashboard roots

每个子目录都是一个独立的 Terraform 根模块，并拥有独立 State。通过项目根目录的 Makefile 执行对应 Dashboard 的命令。

## 迁移已有本地 State

从旧版根目录结构升级时，先执行 `make migrate-<dashboard-name>`。该命令只会在目标 State 不存在时移动根目录的 `terraform.tfstate` 和可选备份；源、目标同时存在或 State 被锁定时会失败，避免覆盖数据。

迁移后必须执行 `make plan-<dashboard-name>`，并确认已有资源对应的 Plan 为 `No changes`。团队环境建议使用加密远程 Backend，从根本上避免 State 依赖单台机器。

## 新增 Dashboard

1. 在 `dashboards/<dashboard-name>/` 创建独立 Terraform 配置。
2. 声明共享变量 `posthog_host`、`posthog_project_id` 和 `posthog_api_key`。
3. 将非敏感业务配置写入该目录的 `dashboard.tfvars.json`。
4. 在根目录 `Makefile` 的 `DASHBOARDS` 中登记名称。
5. 执行 `make init-<dashboard-name>`、`make plan-<dashboard-name>` 和 `make apply-<dashboard-name>`。

不要让两个 Dashboard 目录共用同一个 `terraform.tfstate`，也不要使用 `-target` 代替 State 隔离。
