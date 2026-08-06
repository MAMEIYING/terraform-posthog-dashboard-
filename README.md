# PostHog Dashboards with Terraform

这个项目使用 PostHog 官方 Terraform Provider 管理多个 Dashboard。每个 Dashboard 都是独立的 Terraform 根模块和独立 State，通过专属 Make 命令创建、更新或删除，不会影响其他 Dashboard。

## 项目结构

```text
terraform-posthog-dashboard/
├── Makefile                         # Dashboard 命令入口
├── terraform.tfvars                 # 共享连接参数和 API Key，禁止提交
├── terraform.tfvars.example         # 共享参数示例
├── dashboards/
│   ├── README.md                     # 新增 Dashboard 说明
│   └── intake-error/                 # 独立 Terraform 根模块和 State
│       ├── dashboard.tfvars.json     # 可提交的 Dashboard 业务配置
│       ├── main.tf
│       ├── outputs.tf
│       ├── provider.tf
│       ├── variables.tf
│       └── versions.tf
└── docs/
    └── intake-error.md               # Intake Error 指标与使用说明
```

## 已支持的 Dashboard

| 命令名称 | PostHog Dashboard | 说明文档 |
| --- | --- | --- |
| `intake-error` | `intake error` | [指标与使用说明](./docs/intake-error.md) |

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

PostHog 原生 Trends 的所有公式序列共用数值格式，无法在保持错误率百分比格式的同时，把分子和分母按整数正确显示在 Hover 中；`BoldNumber` 大数字卡片本身也没有 Hover 数据点。因此当前 Terraform 保留现有百分比展示，没有加入会导致单位错误的分子/分母序列。完整验证结论和后续方案见 [Intake Error 指标与使用说明](./docs/intake-error.md#32-frontend-error-rate)。

趋势 Insight 保留 PostHog 的属性筛选入口，错误列表同时启用时间范围和属性筛选，可用于追加 `tenant_id`、`$host`、`$exception_types` 等条件。

> `posthog_dashboard_layout` 会完整接管 Dashboard 中的所有图块。不要在 PostHog UI 中手动添加需要长期保留、但未写入 Terraform 的图块。

## 前置条件

- Terraform 1.10 或更高版本
- PostHog US Cloud 项目 `92499`
- 具有目标项目权限的 PostHog Personal API Key
- 前端事件需要包含 `$session_id`、`$pathname`、`$host`、`$device_type`、`$raw_user_agent`、`tenant_id`；异常事件还需要包含 `$exception_types` 和 `$exception_values`

## 1. 配置共享 PostHog 参数

根目录的 `terraform.tfvars` 只保存所有 Dashboard 共用的 PostHog 连接参数。该文件被 `.gitignore` 排除：

```hcl
posthog_project_id = "92499"
posthog_api_key    = "phx_your_personal_api_key"
posthog_host       = "https://us.posthog.com"
```

Dashboard 名称、标签、路径等非敏感配置保存在对应目录的 `dashboard.tfvars.json` 中，不要放进共享 `terraform.tfvars`。

`posthog_api_key` 被声明为 `sensitive` 和 `ephemeral`，Terraform 会隐藏命令输出中的值，并避免将变量值写入 Plan 和 State。

如果 `terraform.tfvars` 不存在，可以从示例文件重新创建：

```bash
cp terraform.tfvars.example terraform.tfvars
```

## 2. 使用 Dashboard 专属命令

### 从旧版单 Dashboard 目录升级

如果当前检出环境在项目根目录中已经存在 `terraform.tfstate`，拉取本次目录重构后，必须先迁移 State：

```bash
make migrate-intake-error
make init-intake-error
make plan-intake-error
```

迁移命令具有以下保护：

- 目标 State 已存在且根目录 State 不存在时，按“已迁移”安全退出。
- 根目录和目标目录同时存在 State 时立即失败，不覆盖任何文件。
- Terraform 正在持有 State Lock 时立即失败。
- 同步迁移 `terraform.tfstate.backup`，但不会覆盖已有备份。

`plan` 必须显示 `No changes`，才能继续执行 `apply`。如果旧 Dashboard 存在但找不到旧 State，不要执行 `apply`；应先恢复 State、配置远程 Backend，或导入现有资源。

旧版根目录 `terraform.tfvars` 还可能包含 `dashboard_name`、`dashboard_tags`、`intake_path` 和 `tenant_property`。这些字段现在由 `dashboards/intake-error/dashboard.tfvars.json` 管理，应从根目录文件移除，只保留三个共享 PostHog 参数。

### 日常命令

`intake-error` 的完整工作流：

```bash
make init-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
make apply-intake-error
```

查看输出和 State：

```bash
make output-intake-error
make state-list-intake-error
```

删除时必须明确指定 Dashboard：

```bash
make destroy-intake-error
```

也可以使用通用命令，效果相同：

```bash
make plan DASHBOARD=intake-error
make apply DASHBOARD=intake-error
```

`make apply-intake-error` 只读取：

- 根目录 `terraform.tfvars`：共享 PostHog 连接信息。
- `dashboards/intake-error/dashboard.tfvars.json`：该 Dashboard 的业务配置。
- `dashboards/intake-error/terraform.tfstate`：该 Dashboard 的独立本地 State。

## 3. 新增 Dashboard

1. 创建 `dashboards/<dashboard-name>/` 独立根模块。
2. 创建该 Dashboard 的 `dashboard.tfvars.json`。
3. 在 `Makefile` 的 `DASHBOARDS` 中登记名称。
4. 依次执行 `make init-<dashboard-name>`、`make plan-<dashboard-name>` 和 `make apply-<dashboard-name>`。

详细约束见 [dashboards/README.md](./dashboards/README.md)。不要通过 `-target` 在一个 State 中分别创建 Dashboard，也不要复制其他 Dashboard 的 State。

## 安全说明

- 根目录 `terraform.tfvars`、Terraform State 和 Plan 文件已加入 `.gitignore`。
- `dashboard.tfvars.json` 只能保存非敏感业务配置。
- `terraform.tfvars.example` 只能保留占位值，不要写入真实 API Key。
- Terraform State 可能包含资源信息；团队环境建议使用加密的远程 Backend。
- 不要强制提交 Personal API Key、State 文件或包含敏感值的执行日志。
