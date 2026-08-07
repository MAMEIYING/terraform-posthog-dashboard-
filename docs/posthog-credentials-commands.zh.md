# 更新 PostHog 项目凭证后的 Terraform 执行命令

> [English](./posthog-credentials-commands.md) | 中文

本文说明在更新 `posthog_project_id` 和 `posthog_api_key` 后，如何验证并应用本仓库管理的 PostHog Dashboard。

## 1. 更新共享连接配置

在项目根目录更新被 Git 忽略的 `terraform.tfvars`：

```hcl
posthog_project_id = "新的项目 ID"
posthog_api_key    = "新的 Personal API Key"
posthog_host       = "https://us.posthog.com"
```

API Key 必须是能够访问目标项目的 PostHog Personal API Key。不要提交或输出真实密钥。建议限制配置文件的本地访问权限：

```bash
chmod 600 terraform.tfvars
```

如果文件尚不存在，先从示例创建，再使用编辑器填入真实值：

```bash
cp terraform.tfvars.example terraform.tfvars
```

## 2. 初始化并验证两个 Dashboard

以下命令都应从项目根目录执行。

### Intake Error

```bash
make init-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
```

### Intake Performance

```bash
make init-intake-performance
make fmt-check-intake-performance
make validate-intake-performance
make plan-intake-performance
```

## 3. 检查 Plan 并决定是否 Apply

- 如果 Plan 显示 `No changes`，说明目标项目中的资源与 Terraform 配置一致，无需执行 Apply。
- 如果 Plan 仅包含预期变更，审查资源创建、更新和删除数量后，再分别执行对应 Apply。
- 如果出现 `401`、`403` 或 `404`，先检查 Project ID、Personal API Key 权限和 PostHog Host，不要继续 Apply。
- 如果 Plan 准备批量重建或删除资源，应立即停止并检查目标项目与本地 State 是否匹配。

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

## 4. 全新 PostHog 项目注意事项

本仓库的两个 Dashboard 使用独立的本地 State。仅修改 `posthog_project_id` 不会自动把旧项目资源迁移到新项目。

如果目标是全新的空 PostHog 项目，不要使用保存了旧项目资源 ID 的 State 直接 Apply。应先为新项目确定独立 State 策略，再创建资源；如果新项目中已经存在对应资源，则应先导入，而不是创建副本。
