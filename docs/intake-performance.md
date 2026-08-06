# Intake Performance Dashboard 指标与使用说明

> 同步日期：2026-08-06
>
> PostHog 项目：`92499`
>
> Dashboard：[intake performance](https://us.posthog.com/project/92499/dashboard/1956103)

## 1. Dashboard 目标

该 Dashboard 用于观察 `/intake` 页面最近 24 小时的 Web Vitals 与访问量，包括 INP、LCP、FCP、CLS 的 P75/P90/P99、LCP 慢加载比例，以及 PV/UV 总量和上一周期对比趋势。

## 2. 全局范围

| 配置 | 当前值 | 说明 |
| --- | --- | --- |
| Dashboard 顶部时间范围 | 最近 24 小时 | PostHog 保存值为 `-24h`，Provider 当前不管理该字段 |
| HogQL 与 PV/UV Insight | 最近 24 小时 | Insight 自身保存为 `-24h` |
| Web Vitals Trends | 最近 1 小时 | Insight 自身保存为 `-1h`；在 Dashboard 内被顶部 `-24h` 覆盖 |
| Dashboard 顶部趋势粒度 | `hour` | 慢 LCP 卡自身保存为 `minute`，在 Dashboard 内被顶部设置覆盖 |
| 页面路径 | `/intake` | 除 Derived 面板外，统一使用 Web Analytics 的 cleaned path 口径 |
| 对比 | 上一周期 | PV/UV 趋势启用对比 |
| 测试账号过滤 | 未启用 | Trends 查询中 `filterTestAccounts = false` |

## 3. 面板清单

| 顺序 | 面板 | 统计口径 | 布局 |
| ---: | --- | --- | --- |
| 1 | Derived - Intake LCP slow-load ratio | LCP 大于 4000 ms 的 `$web_vitals` 数量 ÷ 有 LCP 值的数量 × 100，以 `%` 后缀展示 | 12 列大数字卡 |
| 2–5 | INP/LCP/FCP/CLS P75 | 按小时计算 P75；INP/LCP/FCP 取最后一个非零桶，CLS 在区间内有非零数据时取最后一个桶 | 4 个等宽大数字卡 |
| 6–9 | INP/LCP/FCP/CLS P75/P90/P99 | 按小时展示三个百分位趋势 | 2 × 2 趋势图 |
| 10–11 | PV/UV total | 仅统计有效 session；PV 使用 `count()`，UV 使用 `uniq(person_id)` | 2 个等宽大数字卡 |
| 12–13 | PV/UV trend | 按小时展示当前周期与上一周期 | 2 个等宽趋势图 |

## 4. Web Analytics 对齐口径

除 `Derived - Intake LCP slow-load ratio` 外，所有面板都以 PostHog Web Analytics 模块为数据标准：

- Web Vitals 使用 `$web_vitals` 事件、Web Analytics cleaned path 和对应数值属性的 P75/P90/P99。
- P75 数字卡复刻 Web Vitals 顶部指标的取值逻辑：INP/LCP/FCP 回退到最后一个非零桶；CLS 在区间内出现过非零值后展示最后一个桶。
- PV/UV total 只统计 PostHog 已解析出 `$session_id_uuid` 的 `$pageview`；PV 统计事件数，UV 按 `person_id` 使用 PostHog Web Overview 同口径的 `uniq` 聚合。
- PV/UV trend 使用 Web Analytics 原生 Trends 查询结构、cleaned path、当前周期与上一周期对比。

## 5. Terraform 管理范围

`dashboards/intake-performance` 管理以下既有 PostHog 资源：

- Dashboard `1956103` 的名称、描述、Pinned 状态和标签。
- 13 个 Insight 的名称、描述、标签、查询与展示配置。
- 13 个图块的顺序、尺寸和位置。

PostHog Provider `1.0.x` 当前不暴露 Dashboard 的文件夹和顶部全局筛选字段，因此 Terraform 不管理 `Unfiled/Dashboards` 文件夹、Dashboard 顶部保存的 `-24h` 时间范围和 `hour` 粒度。Terraform 会精确保留各 Insight 自身保存的查询值；当前 Dashboard 中 Web Vitals 的 24 小时/小时展示仍依赖顶部筛选，请不要在 PostHog UI 中清除或改写这些顶部默认值。

`posthog_dashboard_layout` 会完整接管 Dashboard 中的所有图块。不要在 PostHog UI 中手动添加需要长期保留、但未写入 Terraform 的图块。

## 6. 导入既有资源

该目录对应已有 Dashboard，首次在一个新的本地环境中使用时必须先导入，禁止直接 `apply`，否则 Terraform 会尝试创建副本。

```bash
make init-intake-performance
make import-intake-performance
```

导入脚本会把 Dashboard、13 个 Insight 和 Dashboard Layout 导入到同一个独立 State；重复执行时会跳过已经纳管的资源。当前资源 ID 与 Terraform Key 的对应关系如下：

| Terraform Key | PostHog Insight ID |
| --- | ---: |
| `derived_intake_lcp_slow_load_ratio` | `10761331` |
| `intake_inp_p75_web_analytics` | `10790939` |
| `intake_lcp_p75_web_analytics` | `10790992` |
| `intake_fcp_p75_web_analytics` | `10791107` |
| `intake_cls_p75_web_analytics` | `10791201` |
| `intake_inp_p75_p90_p99` | `10761218` |
| `intake_lcp_p75_p90_p99` | `10761203` |
| `intake_fcp_p75_p90_p99` | `10761205` |
| `intake_cls_p75_p90_p99` | `10761220` |
| `intake_pv_total_web_analytics` | `10791974` |
| `intake_uv_total_web_analytics` | `10791894` |
| `intake_pv_trend_web_analytics` | `10791526` |
| `intake_uv_trend_web_analytics` | `10791435` |

Layout 的导入 ID 与 Dashboard ID 相同：`1956103`。完成全部导入后执行：

```bash
make plan-intake-performance
```

只有在 Plan 确认不会创建或删除 Dashboard/Insight，并且所有更新都经过审查后，才可以执行 `make apply-intake-performance`。
