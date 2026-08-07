# Intake 告警

> [English](./alerts.md) | 中文

本文说明由独立 Terraform 根模块 `dashboards/intake-alerts` 纳管的三个 Intake 告警。目标 PostHog 项目由根目录 `terraform.tfvars` 中的 `posthog_project_id` 动态指定。该栈可以从空 State 创建资源，也可以在恢复既有 State 时导入资源。

所有有 State 的 Make 命令会自动使用 `project-<posthog_project_id>` Terraform Workspace。因此修改 Project ID 后会切换到隔离的 State，不会再刷新上一个项目的资源。

## 纳管资源

| 类型 | 数量 | Terraform 资源 |
| --- | ---: | --- |
| HogQL Insight | 3 | `posthog_insight.intake_alert` |
| HogQL Alert | 3 | `restapi_object.intake_alert` |
| Slack Destination | 6 | `posthog_hog_function.slack_alert` |

PostHog 官方 Provider 当前没有暴露这些告警使用的 `HogQLAlertConfig` 字段，因此 Alert 对象由 `Mastercard/restapi` 管理，Insight 和 Slack Destination 仍使用官方 Provider。

## 告警定义

| 级别 | 告警 | 触发条件 | 检查周期 |
| --- | --- | --- | --- |
| P0 | `[P0] Intake LCP critical (10m, n>=20)` | 10 分钟内按页面浏览去重的 LCP 样本至少 20 个，并且最近 5 分钟 LCP P95 超过 15 秒，或最近 10 分钟超过 20% 的样本大于 10 秒 | 每小时 |
| Warning | `[Warning] Intake LCP P95 > 8s (10m, n>=20)` | 10 分钟内按页面浏览去重的 LCP 样本至少 20 个，并且 LCP P95 超过 8 秒 | 每小时 |
| Warning | `[Warning]Intake Frontend error count >= 3 / 15m` | `/intake` 在 15 分钟内出现至少 3 个 `$exception` 事件 | 每小时 |

三个 Insight 都会返回一个二值触发列。Alert 读取最后一行，并在该列大于 `0` 时触发。

## 数据口径

- PostHog 项目/环境：读取根目录 `terraform.tfvars` 中的 `posthog_project_id`
- 页面：`$pathname = /intake`
- LCP 事件：`$web_vitals`
- LCP 属性：`$web_vitals_LCP_value`
- LCP 去重键：`$pageview_id`
- 前端错误事件：`$exception`
- 三个告警均已启用，周末不会跳过检查。

## Slack Destination

每个 Alert 都连接到以下两个已纳管 Slack 频道：

| 频道 | Channel ID | PostHog Slack Integration ID |
| --- | --- | ---: |
| `#test-alert` | `C0BNBQPRL5U` | `158650` |
| `#fd-launchpad-intake-monitor-staging` | `C0BPGL1AD4G` | `158650` |

六个 `internal_destination` Hog Function 按 Alert UUID 筛选 `$insight_alert_firing` 事件，并使用 PostHog 标准 Slack 告警消息，包含查看 Alert、查看 Insight 和 Snooze 操作。

## 当前已部署资源 ID（`341180`）

| Key | Insight ID | Alert UUID |
| --- | ---: | --- |
| `p0_lcp` | `10827279` | `019fdb12-c134-0000-35e8-7bfaa38c20e8` |
| `warning_lcp` | `10827280` | `019fdb12-c12f-0000-5cf7-140c110c7205` |
| `frontend_error` | `10827281` | `019fdb12-c122-0000-3e43-a20d77a2e3fc` |

| Destination Key | Hog Function UUID |
| --- | --- |
| `frontend_error_staging` | `019fdb14-8e1b-0000-a957-7cc5c68f2d05` |
| `frontend_error_test_alert` | `019fdb14-8f68-0000-a50b-98cdc1c866a3` |
| `p0_lcp_staging` | `019fdb14-8e0a-0000-5772-446391cfc81d` |
| `p0_lcp_test_alert` | `019fdb14-8e20-0000-fa19-c5803432b1d8` |
| `warning_lcp_staging` | `019fdb14-8e0d-0000-e1ba-3c3774b7bade` |
| `warning_lcp_test_alert` | `019fdb14-8f52-0000-eafc-55fa37a63b62` |

## 导入与验证

Personal API Key 在导入和 Plan 阶段需要 `insight:read`、`alert:read` 和 `hog_function:read`。执行变更需要 `insight:write`、`alert:write` 和 `hog_function:write`。

全新部署时，依次完成初始化、验证、审核预期的 12 个新建动作并执行 Apply：

```bash
make init-intake-alerts
make workspace-new-intake-alerts
make validate-intake-alerts
make plan-intake-alerts
make apply-intake-alerts
```

Workspace 只创建一次。如果已经存在，直接执行 `make workspace-show-intake-alerts` 和 `make plan-intake-alerts`。

如果 PostHog 资源已经存在，但需要恢复本地 State，应先导入再执行 Plan：

```bash
make init-intake-alerts
make workspace-new-intake-alerts
make import-intake-alerts
make plan-intake-alerts
```

仓库中的固定恢复导入映射只适用于项目 `341180`；脚本会拒绝在其他项目复用这些 ID。切换到新项目时，应创建空 Workspace 并审核预期的 12 个新建动作，而不是导入 `341180` 的 ID。

迁移旧 Dashboard `default` State 时，`terraform.tfvars` 必须仍选择 State 中记录的项目：

```bash
make migrate-intake-alerts
make workspace-show-intake-alerts
```

恢复 State 时，在全部既有对象导入且 Plan 完成审核前，不要执行 `apply`。REST Provider 在导入时会有意保存完整的服务器响应，但不会加载资源级读取归一化配置。因此，即使纳管字段已经一致，首次恢复 Plan 仍会为三个 `restapi_object.intake_alert` 各显示一次原地更新；此时 Insight 与 Slack Destination 必须无变更，并且不能出现替换、新建或删除。

首次 Apply 需要 `alert:write`，并会向三个 Alert 发送幂等 `PATCH`。完成后，`read_search.search_patch` 会将 PostHog 响应收敛为纳管字段，使日常 Plan 能检测有效 Drift，同时忽略时间戳、检查历史、创建人元数据和嵌套 Insight 数据。不要为了归一化 State 而 Apply 范围更大的 Plan。

## PostHog 链接

- [P0 LCP Insight](https://us.posthog.com/project/341180/insights/IGZa5JvF)
- [Warning LCP Insight](https://us.posthog.com/project/341180/insights/oZUGcMWs)
- [Frontend Error Insight](https://us.posthog.com/project/341180/insights/Qx9cDC7s)
- [告警列表](https://us.posthog.com/project/341180/alerts)

## 调度限制

当前套餐每小时检查一次。10 分钟或 15 分钟的短窗口异常可能延迟通知，15 分钟前端错误条件还可能完整发生在两次检查之间。PostHog 套餐支持且运维成本可接受时，应考虑使用更短的检查周期。
