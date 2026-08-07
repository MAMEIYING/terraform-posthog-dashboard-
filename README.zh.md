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

## Intake Error Dashboard

Intake Error Dashboard 用于监控 `/intake` 页面上的前端异常，包括错误数量、受影响会话比例、时间趋势、问题归因和最近事件详情。所有指标默认查询最近一天，精确匹配 `$pathname = "/intake"`，趋势图使用小时粒度。

面板定义、查询语义、验证结果、筛选建议和 Terraform 管理边界详见[中文说明](./docs/intake-error.zh.md)或[英文说明](./docs/intake-error.md)。

## Intake Performance Dashboards

两个 Intake Performance Dashboard 共同用于观察 `/intake` 页面性能。Overview 通过 Web Vitals P75 趋势、Poor ratio、指标覆盖率和 PV/UV 监控最近 24 小时的健康状况；Diagnostics 通过 P75/P90/P99 趋势、Tenant、Organization、Domain 维度明细和逐次 Web Vitals 上报排查最近七天的问题。

面板定义、查询语义、数据质量结论、筛选建议和 Terraform 管理边界详见[中文说明](./docs/intake-performance.zh.md)或[英文说明](./docs/intake-performance.md)。

## 前置条件

- Terraform 1.10 或更高版本
- POSIX 兼容 Shell、`curl` 和 `jq`；Intake Performance 清理步骤会在 `terraform apply` 期间调用它们
- PostHog US Cloud 项目 `92499`
- 具有目标项目访问权限的 PostHog Personal API Key
- 前端事件包含 `$session_id`、`$pathname`、`$host`、`$device_type`、`$raw_user_agent` 和 `tenant_id`；Exception 事件还必须包含 `$exception_types` 和 `$exception_values`

### 在 macOS 上安装 Terraform

如果终端显示 `/bin/sh: terraform: command not found`，请先安装 Terraform，再执行任何 Dashboard 命令。推荐使用 HashiCorp 官方 Homebrew Tap 安装：

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

确认 `terraform version` 显示 Terraform 1.10.0 或更高版本。如果无法使用 Homebrew，请从 [Terraform 官方安装页面](https://developer.hashicorp.com/terraform/install)下载对应的 macOS 二进制文件，并将其放入 `PATH` 包含的目录。

PostHog Provider 不需要单独手动安装。请先初始化 Dashboard，让 Terraform 自动下载所需 Provider：

```bash
make init-intake-error
```

初始化成功后，再依次执行 `make plan-intake-error` 和 `make apply-intake-error`。

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
