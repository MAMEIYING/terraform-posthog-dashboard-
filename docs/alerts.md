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
