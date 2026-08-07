# 更新 PostHog 项目凭证后的 Terraform 执行命令

> [English](./posthog-credentials-commands.md) | 中文

本文说明在更新 `posthog_project_id` 和 `posthog_api_key` 后，如何使用项目级 Terraform Workspace 验证并应用本仓库管理的 PostHog Dashboard。

## 1. 更新共享连接配置

在项目根目录更新被 Git 忽略的 `terraform.tfvars`：

```hcl
posthog_project_id = "新的项目 ID"
posthog_api_key    = "新的 Personal API Key"
posthog_host       = "https://us.posthog.com"
```

API Key 必须能够访问目标项目。不要提交或输出真实密钥，建议限制配置文件的本地访问权限：

```bash
chmod 600 terraform.tfvars
```

如果文件尚不存在，先从示例创建，再使用编辑器填入真实值：

```bash
cp terraform.tfvars.example terraform.tfvars
```

Makefile 会从该文件读取 `posthog_project_id`，并将所有有 State 的命令绑定到 `project-<posthog_project_id>`。例如，项目 `341180` 自动使用 `project-341180`。命令不会依赖当前交互式选中的 Workspace。

## 2. 初始化并准备项目 Workspace

以下命令都应从项目根目录执行。每个 Dashboard 根模块都需要创建自己的同名项目 Workspace。

### Intake Error

```bash
make init-intake-error
make workspace-list-intake-error
make workspace-new-intake-error   # 仅在 project-<ID> 不存在时执行一次
make workspace-show-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
```

### Intake Performance

```bash
make init-intake-performance
make workspace-list-intake-performance
make workspace-new-intake-performance   # 仅在 project-<ID> 不存在时执行一次
make workspace-show-intake-performance
make fmt-check-intake-performance
make validate-intake-performance
make plan-intake-performance
```

如果派生出的 Workspace 不存在，`plan`、`apply`、`destroy`、`output`、`state-list` 和 `import-intake-performance` 会立即失败，并提示对应的 `workspace-new` 命令。它们不会退回 `default` 或复用其他项目的 State。

## 3. 检查 Plan 并决定是否 Apply

- 如果 Plan 显示 `No changes`，说明目标项目中的资源与 Terraform 配置一致，无需 Apply。
- 如果 Plan 仅包含预期变更，审查资源创建、更新和删除数量后，再分别执行对应 Apply。
- 如果出现 `401`、`403` 或 `404`，先检查 Project ID、Personal API Key 权限和 PostHog Host。
- 如果 Plan 准备批量重建或删除资源，应立即停止并检查项目 Workspace 中的 State。

确认 Plan 符合预期后执行：

```bash
make apply-intake-error
make apply-intake-performance
```

Apply 完成后，可查看 Dashboard 输出和 State：

```bash
make output-intake-error
make state-list-intake-error
make output-intake-performance
make state-list-intake-performance
```

## 4. 切换或新增 PostHog 项目

修改 `posthog_project_id` 会切换 Makefile 使用的项目 Workspace，但不会把旧项目资源迁移到新项目。

- **全新空项目：** 为每个 Dashboard 执行一次对应的 `workspace-new`，审查创建计划后再 Apply。
- **目标项目已有资源：** 先创建项目 Workspace，再导入目标项目中的真实资源 ID，禁止直接 Apply 创建副本。
- **旧版本地 State：** `make migrate-<dashboard-name>` 可将根目录或 Dashboard `default` State 移入当前 `project-<ID>`；源和目标同时存在或 State 被锁定时会拒绝迁移。

`make import-intake-performance` 中的固定资源映射仅适用于 PostHog 项目 `92499`。脚本会拒绝在其他项目或不匹配的 Workspace 中运行。
