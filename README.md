# Intake Error Dashboard with Terraform

这个项目使用 PostHog 官方 Terraform Provider，在项目 `92499` 中创建面向开发人员的 `intake error` Dashboard。

## Dashboard 内容

所有指标默认查询最近 1 天，并且只统计 `$pathname` **精确等于** `/intake` 的数据。趋势图统一按小时聚合。

| 图块 | 定义 |
| --- | --- |
| Frontend error count | `$exception` 事件总数 |
| Frontend error rate | 发生 `$exception` 的唯一 Intake 会话数 ÷ 访问 Intake 的唯一 `$pageview` 会话数 × 100% |
| Frontend error trend | 按小时统计错误数量 |
| Frontend error rate trend | 按小时统计发生错误的 Intake 会话比例 |
| Top error issues | 按 `$exception_issue_id` 拆分前 10 个错误问题趋势 |
| Unhandled error trend | 按小时统计 `$exception_handled = false` 的错误数量 |
| Errors by type | 按 `$exception_types` 拆分错误趋势 |
| Errors by domain | 按 `$host` 拆分错误趋势 |
| Errors by tenant | 按 `tenant_id` 拆分错误趋势 |
| Errors by browser | 按 `$browser` 拆分前 10 个浏览器错误趋势 |
| Frontend error list | 最近错误的时间、租户、Domain、异常级别、类型、消息、来源、URL、Issue ID、Session ID、浏览器、操作系统、设备、Replay 状态、Intake 表单版本和用户 ID |

### 错误率分母验证与展示限制

`Frontend error rate` 的分母来自 `/intake` `$pageview` 事件的 `unique_session` 聚合，不是 Pageview 事件总数。2026-08-06 对最近 7 天数据的验证结果为：39 个 `$pageview` 事件、11 个 Pageview 唯一会话、0 个 `$exception` 事件、0 个 Exception 唯一会话，因此错误率为 `0 ÷ 11 = 0%`。这证明当前分母查询链路可用，但仍需持续监控 `$pageview` 的 `$session_id`、`$pathname`、`$host` 和 `tenant_id` 属性覆盖率。

PostHog 原生 Trends 的所有公式序列共用数值格式，无法在保持错误率百分比格式的同时，把分子和分母按整数正确显示在 Hover 中；`BoldNumber` 大数字卡片本身也没有 Hover 数据点。因此当前 Terraform 保留现有百分比展示，没有加入会导致单位错误的分子/分母序列。完整验证结论和后续方案见 [DASHBOARD_GUIDE.md](./DASHBOARD_GUIDE.md#32-frontend-error-rate)。

趋势 Insight 保留 PostHog 的属性筛选入口，错误列表同时启用时间范围和属性筛选，可用于追加 `tenant_id`、`$host`、`$exception_types` 等条件。

> `posthog_dashboard_layout` 会完整接管 Dashboard 中的所有图块。不要在 PostHog UI 中手动添加需要长期保留、但未写入 Terraform 的图块。

## 前置条件

- Terraform 1.10 或更高版本
- PostHog US Cloud 项目 `92499`
- 具有目标项目权限的 PostHog Personal API Key
- 前端事件需要包含 `$session_id`、`$pathname`、`$host`、`$device_type`、`$raw_user_agent`、`tenant_id`；异常事件还需要包含 `$exception_types` 和 `$exception_values`

## 1. 配置 Personal API Key

项目包含一个被 `.gitignore` 排除的 `terraform.tfvars`。只需要将其中的占位值替换为真实 Personal API Key：

```hcl
posthog_api_key = "phx_your_personal_api_key"
```

关键配置如下：

```hcl
posthog_project_id = "92499"
posthog_host       = "https://us.posthog.com"
dashboard_name     = "intake error"
intake_path        = "/intake"
tenant_property    = "tenant_id"
```

`posthog_api_key` 被声明为 `sensitive` 和 `ephemeral`：Terraform 会隐藏命令输出中的值，并避免将变量值写入 Plan 和 State。

如果 `terraform.tfvars` 不存在，可以从示例文件重新创建：

```bash
cp terraform.tfvars.example terraform.tfvars
```

## 2. 初始化并验证

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

## 3. 创建 Dashboard

```bash
terraform apply
```

成功后，Terraform 会输出 Dashboard ID、Dashboard URL，以及全部 Insight ID。

## 4. 删除 Terraform 管理的资源

```bash
terraform destroy
```

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `versions.tf` | Terraform 与 Provider 版本约束 |
| `provider.tf` | PostHog Provider 配置 |
| `variables.tf` | 项目、Dashboard、路径和租户字段配置 |
| `main.tf` | Dashboard、11 个 Insight 和布局资源 |
| `outputs.tf` | Dashboard 与 Insight 输出 |
| `terraform.tfvars.example` | 可提交的占位配置示例，不包含真实凭证 |
| `terraform.tfvars` | 本地真实配置，包含 API Key，已被 Git 忽略 |

## 安全说明

- `terraform.tfvars`、其他 `.tfvars` 文件和 Terraform State 已加入 `.gitignore`。
- `terraform.tfvars.example` 只能保留占位值，不要写入真实 API Key。
- Terraform State 可能包含资源信息；团队环境建议使用加密的远程 Backend。
- 不要强制提交 Personal API Key、State 文件或包含敏感值的执行日志。
