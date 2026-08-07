# 📊 三个新增告警配置汇总

## 中文版

| 级别 | 告警名称 | 触发条件 | 检查周期 | 通知 |
|---|---|---|---|---|
| P0 | `[P0] Intake LCP critical (10m, n>=20)` | 最近10分钟 LCP 样本≥20，并且最近5分钟 LCP P95>15秒，或最近10分钟超过20%的 LCP>10秒 | 每小时（prod调整为in real time） | Slack `#test-alert`(prod需调整channel) |
| Warning | `[Warning] Intake LCP P95 > 8s (10m, n>=20)` | 最近10分钟 LCP 样本≥20，并且 LCP P95>8秒 | 每小时(prod调整为in real time) | Slack `#test-alert`(prod需调整channel) |
| Warning | `[Warning] Frontend error count >= 3 / 15m` | `/intake` 最近15分钟出现≥3个 `$exception` 事件 | 每小时(prod调整为15min) | Slack `#test-alert` (prod需调整channel)|

### 数据口径

- 页面：`$pathname = /intake`
- LCP 事件：`$web_vitals`
- LCP 属性：`$web_vitals_LCP_value`
- LCP 样本按 `$pageview_id` 去重
- 前端错误事件：`$exception`
- 三个告警均已启用
- 创建完成时均为 `Not firing`
- Slack 频道 ID：`C0BNBQPRL5U`

### 相关链接

- [P0 LCP Insight](https://us.posthog.com/project/92499/insights/wxkmejBr)
- [Warning LCP Insight](https://us.posthog.com/project/92499/insights/2cRxHmLf)
- [Frontend Error Insight](https://us.posthog.com/project/92499/insights/snv80mt5)
- [告警列表](https://us.posthog.com/project/92499/alerts)

> ⚠️ 当前套餐每小时检查一次。短窗口异常可能延迟通知；15分钟前端错误窗口还可能在两次检查之间被遗漏。

## English Summary

| Severity | Alert condition | Schedule | Destination |
|---|---|---|---|
| P0 | 10-minute samples ≥20 and either 5-minute LCP P95 >15s or >20% of 10-minute loads exceed 10s | Hourly | `#test-alert` |
| Warning | 10-minute samples ≥20 and LCP P95 >8s | Hourly | `#test-alert` |
| Warning | At least 3 `$exception` events on `/intake` within 15 minutes | Hourly | `#test-alert` |
# Intake alerts

> English | [中文](./alerts.zh.md)

This document describes the three Intake alerts managed by the independent `dashboards/intake-alerts` Terraform root module. The target PostHog project is selected dynamically by `posthog_project_id` in the root `terraform.tfvars`. The stack creates the resources from an empty state and can import them when recovering an existing state.

Stateful Make commands automatically use the `project-<posthog_project_id>` Terraform Workspace. Changing the Project ID therefore selects an isolated State instead of refreshing resources from the previous project.

## Managed resources

| Type | Count | Terraform resource |
| --- | ---: | --- |
| HogQL insights | 3 | `posthog_insight.intake_alert` |
| HogQL alerts | 3 | `restapi_object.intake_alert` |
| Slack destinations | 6 | `posthog_hog_function.slack_alert` |

The official PostHog Provider does not currently expose the `HogQLAlertConfig` fields used by these alerts. The alert objects are therefore managed through `Mastercard/restapi`, while insights and Slack destinations continue to use the official Provider.

## Alert definitions

| Severity | Alert | Condition | Evaluation |
| --- | --- | --- | --- |
| P0 | `[P0] Intake LCP critical (10m, n>=20)` | At least 20 deduplicated LCP samples in 10 minutes, and either the latest 5-minute LCP P95 is above 15 seconds or more than 20% of the 10-minute samples exceed 10 seconds | Hourly |
| Warning | `[Warning] Intake LCP P95 > 8s (10m, n>=20)` | At least 20 deduplicated LCP samples in 10 minutes and LCP P95 is above 8 seconds | Hourly |
| Warning | `[Warning]Intake Frontend error count >= 3 / 15m` | At least 3 `$exception` events on `/intake` in 15 minutes | Hourly |

All three insights return a binary firing column. The alert reads the last row and fires when that column is greater than `0`.

## Data scope

- PostHog project/environment: `posthog_project_id` from the root `terraform.tfvars`
- Path: `$pathname = /intake`
- LCP event: `$web_vitals`
- LCP property: `$web_vitals_LCP_value`
- LCP deduplication key: `$pageview_id`
- Frontend error event: `$exception`
- All three alerts are enabled and do not skip weekends.

## Slack destinations

Each alert is connected to both managed Slack channels:

| Channel | Channel ID | PostHog Slack integration ID |
| --- | --- | ---: |
| `#test-alert` | `C0BNBQPRL5U` | `158650` |
| `#fd-launchpad-intake-monitor-staging` | `C0BPGL1AD4G` | `158650` |

The six `internal_destination` Hog Functions filter `$insight_alert_firing` events by the associated Alert UUID and use the standard PostHog Slack alert message with View Alert, View Insight, and Snooze actions.

## Current deployed resource IDs (`341180`)

| Key | Insight ID | Alert UUID |
| --- | ---: | --- |
| `p0_lcp` | `10827279` | `019fdb12-c134-0000-35e8-7bfaa38c20e8` |
| `warning_lcp` | `10827280` | `019fdb12-c12f-0000-5cf7-140c110c7205` |
| `frontend_error` | `10827281` | `019fdb12-c122-0000-3e43-a20d77a2e3fc` |

| Destination key | Hog Function UUID |
| --- | --- |
| `frontend_error_staging` | `019fdb14-8e1b-0000-a957-7cc5c68f2d05` |
| `frontend_error_test_alert` | `019fdb14-8f68-0000-a50b-98cdc1c866a3` |
| `p0_lcp_staging` | `019fdb14-8e0a-0000-5772-446391cfc81d` |
| `p0_lcp_test_alert` | `019fdb14-8e20-0000-fa19-c5803432b1d8` |
| `warning_lcp_staging` | `019fdb14-8e0d-0000-e1ba-3c3774b7bade` |
| `warning_lcp_test_alert` | `019fdb14-8f52-0000-eafc-55fa37a63b62` |

## Import and validate

The Personal API Key needs `insight:read`, `alert:read`, and `hog_function:read` for import and planning. Applying changes requires `insight:write`, `alert:write`, and `hog_function:write`.

For a new deployment, initialize, validate, review the expected 12 creates, and apply:

```bash
make init-intake-alerts
make workspace-new-intake-alerts
make validate-intake-alerts
make plan-intake-alerts
make apply-intake-alerts
```

Create the Workspace only once. If it already exists, continue with `make workspace-show-intake-alerts` and `make plan-intake-alerts`.

If the PostHog resources already exist but local state must be recovered, import them before planning:

```bash
make init-intake-alerts
make workspace-new-intake-alerts
make import-intake-alerts
make plan-intake-alerts
```

The fixed recovery import map in this repository is valid only for project `341180`; the script refuses to reuse those IDs in another project. When switching to a new project, create its empty Workspace and review the expected 12 creates instead of importing the `341180` IDs.

Legacy dashboard `default` State must be migrated while `terraform.tfvars` still selects the project recorded in that State:

```bash
make migrate-intake-alerts
make workspace-show-intake-alerts
```

Do not run `apply` during state recovery until all existing objects have been imported and the plan has been reviewed. The REST provider intentionally imports the complete server response without loading resource-level read normalization. As a result, the first recovery plan is expected to show one in-place update for each of the three `restapi_object.intake_alert` resources even when their managed fields already match. It must show no Insight or Slack destination changes, replacements, creations, or deletions.

That first apply requires `alert:write` and sends an idempotent `PATCH` for the three alerts. Afterward, `read_search.search_patch` reduces PostHog's response to the managed fields so regular plans can detect meaningful drift without tracking timestamps, check history, creator metadata, or nested Insight data. Never apply a broader first plan merely to normalize state.

## PostHog links

- [P0 LCP insight](https://us.posthog.com/project/341180/insights/IGZa5JvF)
- [Warning LCP insight](https://us.posthog.com/project/341180/insights/oZUGcMWs)
- [Frontend error insight](https://us.posthog.com/project/341180/insights/Qx9cDC7s)
- [Alert list](https://us.posthog.com/project/341180/alerts)

## Scheduling limitation

The current plan evaluates alerts hourly. Short-lived 10-minute or 15-minute conditions can be reported late, and a 15-minute frontend-error condition may occur entirely between two checks. Use a shorter evaluation schedule when the PostHog plan supports it and the operational cost is acceptable.
