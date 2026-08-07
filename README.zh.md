# 使用 Terraform 管理 PostHog Dashboards

> [English](./README.md) | 中文

本项目使用 PostHog 官方 Terraform Provider 管理多个 Dashboard。每个 Dashboard 都是独立的 Terraform 根模块，拥有独立 State 和专属 Make 命令，因此创建、更新或删除一个 Dashboard 不会影响其他 Dashboard。

## 项目结构

```text
terraform-posthog-dashboard/
├── Makefile                         # Dashboard 命令入口
├── terraform.tfvars                 # 共享连接配置和 API Key，禁止提交
├── terraform.tfvars.example         # 共享配置示例
├── dashboards/
│   ├── README.md                     # 新增 Dashboard 英文说明
│   ├── README.zh.md                  # 新增 Dashboard 中文说明
│   ├── intake-error/                 # Intake Error 独立根模块和 State
│   │   └── ...
│   └── intake-performance/           # Intake Performance 独立根模块和 State
│       ├── dashboard.tfvars.json     # 可提交的 Dashboard 业务配置
│       ├── diagnostics.tf             # Diagnostics Dashboard 和排查表格
│       ├── main.tf
│       ├── overview-percentiles.tf    # 用于回滚的百分位卡和清理逻辑
│       ├── overview-quality.tf        # Overview 质量和覆盖率卡片
│       ├── outputs.tf
│       ├── provider.tf
│       ├── variables.tf
│       └── versions.tf
├── docs/
│   ├── intake-error.md               # Intake Error 英文指标与使用说明
│   ├── intake-error.zh.md            # Intake Error 中文指标与使用说明
│   ├── intake-performance.md         # Intake Performance 英文指标与使用说明
│   └── intake-performance.zh.md      # Intake Performance 中文指标与使用说明
└── scripts/
    ├── import-intake-performance.sh  # 幂等导入既有 PostHog 资源
    └── cleanup-posthog-dashboard-tiles.sh
                                      # apply 时删除过时 Overview 图块
```

## 已支持的 Dashboard

| 命令名称 | PostHog Dashboard | 说明文档 |
| --- | --- | --- |
| `intake-error` | `Intake Frontend Error` | [English](./docs/intake-error.md) / [中文](./docs/intake-error.zh.md) |
| `intake-performance` | `Intake Performance Overview` 和 `Intake Performance Diagnostics` | [English](./docs/intake-performance.md) / [中文](./docs/intake-performance.zh.md) |

## Intake Error Dashboard 内容

所有指标默认查询最近一天，并且只统计 `$pathname` **精确等于** `/intake` 的事件。趋势图统一使用小时粒度。

| 图块 | 定义 |
| --- | --- |
| Frontend error count | `$exception` 事件总数 |
| Frontend error rate | 发生 `$exception` 的唯一 Intake 会话数 ÷ 访问 Intake 的唯一 `$pageview` 会话数 × 100% |
| Frontend error trend | 按小时统计错误数量 |
| Frontend error rate trend | 按小时统计受错误影响的 Intake 会话比例 |
| Top error issues | 按 `$exception_issue_id` 拆分前 10 个错误问题趋势 |
| Unhandled error trend | 按小时统计 `$exception_handled = false` 的错误数量 |
| Errors by type | 按 `$exception_types` 拆分错误趋势 |
| Errors by domain | 按 `$host` 拆分错误趋势 |
| Errors by tenant | 按 `tenant_id` 拆分错误趋势 |
| Errors by browser | 按 `$browser` 拆分前 10 个浏览器错误趋势 |
| Frontend error list | 最近错误的时间、租户、Domain、异常级别、类型、消息、来源、URL、Issue ID、Session ID、浏览器、操作系统、设备、Replay 状态、Intake 表单版本和用户 ID |

### 错误率分母验证与展示限制

`Frontend error rate` 的分母来自 `/intake` `$pageview` 事件的 `unique_session` 聚合，而不是 Pageview 事件总数。2026-08-06 对最近七天数据的验证结果为：39 个 `$pageview` 事件、11 个 Pageview 唯一会话、0 个 `$exception` 事件、0 个 Exception 唯一会话，因此错误率为 `0 ÷ 11 = 0%`。这证明当前分母查询链路可用，但仍需持续监控 `$pageview` 上 `$session_id`、`$pathname`、`$host` 和 `tenant_id` 的属性覆盖率。

PostHog 原生 Trends 的所有公式序列共用同一种数值格式，无法在保持错误率百分比格式的同时，把分子和分母按整数正确显示在 Hover 中；`BoldNumber` 卡片本身也没有可 Hover 的数据点。因此当前 Terraform 配置保留百分比可视化，不加入会显示错误单位的分子或分母序列。完整验证结论和后续方案见 [Intake Error 指标与使用说明](./docs/intake-error.zh.md#32-frontend-error-rate)。

趋势 Insight 保留 PostHog 属性筛选入口。错误列表同时支持时间范围和属性筛选，可以追加 `tenant_id`、`$host`、`$exception_types` 等条件。

> `posthog_dashboard_layout` 会完整接管 Dashboard 中的所有图块。不要在 PostHog UI 中手动添加需要长期保留、但未在 Terraform 中声明的图块。

## 前置条件

- Terraform 1.10 或更高版本
- POSIX 兼容 Shell、`curl` 和 `jq`；Intake Performance 清理步骤会在 `terraform apply` 期间调用它们
- PostHog US Cloud 项目 `92499`
- 具有目标项目访问权限的 PostHog Personal API Key
- 前端事件包含 `$session_id`、`$pathname`、`$host`、`$device_type`、`$raw_user_agent` 和 `tenant_id`；Exception 事件还必须包含 `$exception_types` 和 `$exception_values`

## 1. 配置共享 PostHog 参数

根目录的 `terraform.tfvars` 只保存所有 Dashboard 共用的 PostHog 连接配置。该文件已被 `.gitignore` 排除：

```hcl
posthog_project_id = "92499"
posthog_api_key    = "phx_your_personal_api_key"
posthog_host       = "https://us.posthog.com"
```

Dashboard 名称、标签和路径等非敏感配置保存在对应目录的 `dashboard.tfvars.json` 中，不要放入共享 `terraform.tfvars`。

`posthog_api_key` 同时声明为 `sensitive` 和 `ephemeral`。Terraform 会隐藏命令输出中的值，并避免将变量值写入 Plan 和 State。

如果 `terraform.tfvars` 不存在，可以从示例文件重新创建：

```bash
cp terraform.tfvars.example terraform.tfvars
```

## 2. 使用 Dashboard 专属命令

### 从旧版单 Dashboard 目录升级

如果当前检出环境的项目根目录中已存在 `terraform.tfstate`，拉取目录重构变更后先迁移 State：

```bash
make migrate-intake-error
make init-intake-error
make plan-intake-error
```

迁移命令包含以下保护：

- 目标 State 已存在且根目录 State 不存在时，按“已经迁移”成功退出。
- 根目录和目标目录同时存在 State 时立即失败，不覆盖任何文件。
- Terraform 正在持有 State Lock 时立即失败。
- 同时迁移 `terraform.tfstate.backup`，但不会覆盖已有备份。

只有 Plan 显示 `No changes` 才能继续 Apply。如果旧 Dashboard 存在但找不到旧 State，不要执行 Apply；应先恢复 State、配置远程 Backend，或导入既有资源。

旧版根目录 `terraform.tfvars` 还可能包含 `dashboard_name`、`dashboard_tags`、`intake_path` 和 `tenant_property`。这些配置现在由 `dashboards/intake-error/dashboard.tfvars.json` 管理，应从根目录文件移除，只保留三个共享 PostHog 参数。

### 日常命令

`intake-error` 的完整工作流为：

```bash
make init-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
make apply-intake-error
```

`intake-performance` 管理既有 Overview Dashboard 和新的 Diagnostics Dashboard，共 31 个 Insight 和两个 Layout。第一次 Apply 前必须导入全部既有资源；完整 ID 映射和命令见 [Intake Performance 指标与使用说明](./docs/intake-performance.zh.md#8-导入既有资源)。在新环境中初始化本地 State：

```bash
make init-intake-performance
make import-intake-performance
```

导入完成后使用以下常规工作流：

```bash
make fmt-check-intake-performance
make validate-intake-performance
make plan-intake-performance
make apply-intake-performance
```

查看 Output 和 State：

```bash
make output-intake-error
make state-list-intake-error
make output-intake-performance
make state-list-intake-performance
```

对于 Intake Performance，`dashboard.tfvars.json` 配置两个 Dashboard 名称、Overview 与 Diagnostics 的滚动时间范围、标签和 Intake 路径。`make output-intake-performance` 返回 Overview ID/URL、Diagnostics ID/URL，以及完整 Insight ID 映射。准确的输入、输出、清理行为和 Provider 限制见 [Intake Performance 管理范围](./docs/intake-performance.zh.md#7-terraform-管理范围)。

Destroy 时必须明确指定 Dashboard：

```bash
make destroy-intake-error
```

也可以使用等价的通用命令：

```bash
make plan DASHBOARD=intake-error
make apply DASHBOARD=intake-error
```

`make apply-intake-error` 只读取：

- 根目录 `terraform.tfvars`：共享 PostHog 连接配置。
- `dashboards/intake-error/dashboard.tfvars.json`：该 Dashboard 的业务配置。
- `dashboards/intake-error/terraform.tfstate`：该 Dashboard 的独立本地 State。

## 3. 新增 Dashboard

1. 在 `dashboards/<dashboard-name>/` 下创建独立根模块。
2. 创建该 Dashboard 的 `dashboard.tfvars.json`。
3. 在根目录 `Makefile` 的 `DASHBOARDS` 中登记名称。
4. 依次执行 `make init-<dashboard-name>`、`make plan-<dashboard-name>` 和 `make apply-<dashboard-name>`。

详细约束见 [dashboards/README.md](./dashboards/README.md)（[中文](./dashboards/README.zh.md)）。不要通过 `-target` 在一个 State 中分别创建 Dashboard，也不要复制其他 Dashboard 的 State。

## 安全说明

- 根目录 `terraform.tfvars`、Terraform State 和 Plan 文件已加入 `.gitignore`。
- `dashboard.tfvars.json` 只能包含非敏感业务配置。
- `terraform.tfvars.example` 只能包含占位值，禁止加入真实 API Key。
- Terraform State 可能包含资源信息；团队环境应使用加密的远程 Backend。
- 不要强制提交 Personal API Key、State 文件或包含敏感值的执行日志。
