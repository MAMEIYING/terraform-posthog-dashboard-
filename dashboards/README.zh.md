# Dashboard 根模块

> [English](./README.md) | 中文

每个子目录都是独立的 Terraform 根模块。每个根模块再按 PostHog 项目使用独立的 `project-<posthog_project_id>` Workspace。请通过项目根目录的 `Makefile` 执行对应 Dashboard 的命令。

## 项目 Workspace

Makefile 从被 Git 忽略的根目录 `terraform.tfvars` 读取 `posthog_project_id`，并对所有有 State 的命令设置命令级 `TF_WORKSPACE`。这意味着 `plan`、`apply`、`destroy`、`output`、`state-list` 和导入命令不会依赖当前交互式选中的 Workspace。

首次管理某个项目时，为每个 Dashboard 创建一次 Workspace：

```bash
make init-<dashboard-name>
make workspace-new-<dashboard-name>
make workspace-show-<dashboard-name>
make plan-<dashboard-name>
```

Workspace 不存在时，有 State 的命令会失败，而不是退回 `default`。不要让不同 PostHog 项目复用同一个 State。

## 迁移已有本地 State

从旧版根目录或 Dashboard `default` State 升级时，确认 `terraform.tfvars` 指向该 State 实际管理的 PostHog 项目，然后执行 `make migrate-<dashboard-name>`。该命令把 State 和可选备份移动到 `terraform.tfstate.d/project-<ID>/`。

根目录与 Dashboard `default` State 同时存在、源与目标 State 同时存在、目标备份已存在或任一 State 被锁定时，迁移会立即失败，不覆盖任何文件。迁移后执行 `make workspace-show-<dashboard-name>` 和 `make plan-<dashboard-name>`；已有资源必须显示 `No changes`。

## 新增栈

1. 在 `dashboards/<stack-name>/` 下创建独立 Terraform 配置。
2. 声明共享变量 `posthog_host`、`posthog_project_id` 和 `posthog_api_key`。
3. 将非敏感业务配置保存在该目录的 `dashboard.tfvars.json` 中。
4. 在根目录 `Makefile` 的 `DASHBOARDS` 中登记名称。
5. 依次执行 `make init-<dashboard-name>`、`make workspace-new-<dashboard-name>`、`make plan-<dashboard-name>` 和 `make apply-<dashboard-name>`。

不要使用 `-target` 代替根模块和项目 Workspace 的 State 隔离。
