# Intake Performance Dashboards 指标与使用说明

> [English](./intake-performance.md) | 中文

> 同步日期：2026-08-06
>
> PostHog 项目：`92499`
>
> Overview：[Intake Performance Overview](https://us.posthog.com/project/92499/dashboard/1956103)
>
> Diagnostics：[Intake Performance Diagnostics](https://us.posthog.com/project/92499/dashboard/1961465)

## 1. Dashboard 目标

两个 Dashboard 共同用于观察 `/intake` 页面性能：

- Overview 面向最近 24 小时健康监控，展示 Web Vitals P75 趋势、Poor ratio、指标覆盖率和 PV/UV。
- Diagnostics 面向最近 7 天问题定位，展示 P75/P90/P99 趋势、Tenant/Organization/Domain 维度明细，以及逐次 Web Vitals 上报列表。

## 2. 全局范围

| 配置 | 当前值 | 说明 |
| --- | --- | --- |
| Overview | 最近 24 小时 | P75 趋势、Coverage 和 PV/UV 自身保存为 `-24h`；4 张比例卡自身保存为 `-1h`。Dashboard 顶部时间范围会覆盖原生 Trends 卡片 |
| Diagnostics | 最近 7 天 | 百分位趋势、维度表和上报列表自身保存为 `-7d` |
| 趋势粒度 | Overview 跟随顶部选择 | P75 趋势自身保存为 `hour`，在 Dashboard 中由顶部 `grouped by` 覆盖；Diagnostics 自身保存为 `hour` |
| 页面路径 | `/intake` | 除 Derived 面板外，统一使用 Web Analytics 的 cleaned path 口径 |
| 对比 | 上一周期 | PV/UV 趋势启用对比 |
| 测试账号过滤 | 未启用 | Trends 查询中 `filterTestAccounts = false` |

## 3. Overview 面板

| 顺序 | 面板 | 统计口径 | 布局 |
| ---: | --- | --- | --- |
| 1–4 | Derived LCP slow-load ratio，以及 INP/FCP/CLS Poor ratio | 指标超过 Poor 阈值的事件数 ÷ 对应指标已设置的事件数；阈值为 LCP 4000 ms、INP 500 ms、FCP 3000 ms、CLS 0.25。LCP 保留旧有 Derived 精确路径查询，其余 3 张卡使用 Web Analytics cleaned-path 口径 | 4 个等宽大数字卡 |
| 5–8 | INP/LCP/FCP/CLS P75 trend | 使用与 Web Analytics 相同的原生 Trends P75 序列；时间范围和分组粒度都接受 Dashboard 顶部覆盖 | 2 × 2 趋势图 |
| 9 | Web Vitals coverage | 对每项指标展示 measured pageviews、总 pageviews 和覆盖率 | 12 列表格 |
| 10–11 | PV/UV total | 仅统计有效 session 且不晚于当前时间；PV 使用 `count()`，UV 使用 `uniq(person_id)` | 2 个等宽大数字卡 |
| 12–13 | PV/UV trend | 按 Dashboard 顶部粒度展示当前周期与上一周期 | 2 个等宽趋势图 |

Overview 只保留四张 P75 原生趋势图，避免固定小时 HogQL 在切换时间范围或 `grouped by` 后继续显示相同的最后小时桶。原有八张 P90/P99 单值 Insight 和状态矩阵继续由 Terraform 纳管，但已从 Overview 脱离，便于需要时恢复。

## 4. Diagnostics 面板

| 顺序 | 面板 | 统计口径 | 布局 |
| ---: | --- | --- | --- |
| 1–4 | INP/LCP/FCP/CLS P75/P90/P99 | 最近 7 天按小时展示三个百分位趋势 | 2 × 2 趋势图 |
| 5 | Diagnostics filters | 说明如何使用 Dashboard Filter 查询 `tenant_id`、`org_id` 和 `$host` | 文本说明 |
| 6 | Dimension coverage | 按 `$pageview_id` 去重后展示 Tenant、Org、Domain 覆盖率与不同值数量 | 12 列表格 |
| 7–9 | Tenant/Organization/Domain performance | 每个维度展示有效 pageview 数、四项指标样本/P75/Poor ratio；缺失值保留为 `(missing)` | 3 张 12 列表格 |
| 10 | Web Vitals reports | 每次 `$web_vitals` 上报占一行，按时间倒序展示性能、业务、实验、页面、设备和会话关键属性 | 12 列表格 |

维度表先按 `$pageview_id` 聚合；同一 pageview 同一指标存在多次上报时取最后一个有效值，避免重复事件影响维度排名。

Web Vitals 上报列表不进行 pageview 去重，也不在 HogQL 中写死 `LIMIT`。PostHog 默认先返回 100 条；存在后续数据时响应包含 `hasMore = true`，表格通过“Load more”继续加载。列依次为上报时间、LCP、INP、FCP、CLS、Tenant、Organization、Program、Intake type、Experiment variant、Intake version、Host、Pathname、Current URL、Device、Browser、OS、Session ID 和 Pageview ID。列表沿用 Diagnostics 时间范围、`/intake` cleaned-path 条件和 Dashboard Filter。

## 5. 数据质量与查询口径

2026-08-06 的事件审计结果：

| 事件样本 | Tenant 覆盖 | Org 覆盖 | Domain 覆盖 | 说明 |
| --- | ---: | ---: | ---: | --- |
| 63 条 `$pageview` | 1/63 | 1/63 | 63/63 | Tenant/Org 尚未在自动 pageview 上稳定注册 |
| 20 条 `$web_vitals` 抽样 | 1/20 | 1/20 | 20/20 | 小样本受 API 返回顺序影响，仅作为上报缺失证明 |
| Diagnostics 7 天、245 个去重 pageview | 245/245 | 200/245 | 245/245 | 当前 Dashboard 实际聚合结果；Org 缺失保留为 `(missing)` |

Tenant/Org 过滤目前适合 Web Vitals 诊断，不适合直接解释整体 PV/UV。要让顶部 Tenant/Org 过滤完整覆盖流量指标，前端必须在 `$pageview` 产生前注册 `tenant_id` 和 `org_id`，或补发带这两个属性的 pageview。

每项 Coverage 独立计算，因为 `$web_vitals` 事件可能只包含部分指标。不要把指标缺失解释为性能值 0。

## 6. Web Analytics 对齐口径

除 `Derived - Intake LCP slow-load ratio` 外，所有面板都以 PostHog Web Analytics 模块为数据标准：

- Web Vitals 使用 `$web_vitals` 事件、Web Analytics cleaned path 和对应数值属性的 P75/P90/P99。
- Overview P75 使用原生 TrendsQuery，与 Web Analytics 使用相同的 `$web_vitals` P75 序列，并接受 Dashboard 顶部日期范围和分组粒度覆盖。
- PV/UV total 只统计 PostHog 已解析出 `$session_id_uuid` 的 `$pageview`；PV 统计事件数，UV 按 `person_id` 使用 PostHog Web Overview 同口径的 `uniq` 聚合。
- PV/UV trend 使用 Web Analytics 原生 Trends 查询结构、cleaned path、当前周期与上一周期对比。

Dashboard 顶部属性过滤由 PostHog UI 管理。Provider 当前不能声明这些顶部筛选；查询时使用 Filter 添加 `tenant_id`、`org_id` 或 `$host`，所有 HogQL 表都通过 `{filters}` 接收这些条件。

## 7. Terraform 管理范围

`dashboards/intake-performance` 管理以下 PostHog 资源：

- Overview Dashboard `1956103` 与 Diagnostics Dashboard `1961465`。
- 31 个 Insight 的名称、描述、标签、查询与展示配置。
- Overview 的 13 个 Insight 图块，以及 Diagnostics 的 9 个 Insight 图块和 1 个文本图块。

PostHog Provider `1.0.x` 当前不暴露 Dashboard 的文件夹和顶部全局筛选字段，因此 Terraform 不管理 `Unfiled/Dashboards` 文件夹、Dashboard 顶部保存的 `-24h` 时间范围和 `hour` 粒度。Terraform 会精确保留各 Insight 自身保存的查询值；当前 Dashboard 中 Web Vitals 的 24 小时/小时展示仍依赖顶部筛选，请不要在 PostHog UI 中清除或改写这些顶部默认值。

两个 `posthog_dashboard_layout` 都会完整接管对应 Dashboard 的图块。不要在 PostHog UI 中手动添加需要长期保留、但未写入 Terraform 的图块。

PostHog Provider `1.0.x` 无法通过把既有 Insight 的 `dashboard_ids` 更新为空集合来删除对应 tile，Layout 资源也不会删除未声明的既有 tile。Overview 的 8 个独立 P90/P99 Insight 和原状态矩阵因此使用 Lifecycle 忽略该字段；`terraform_data.intake_performance_overview_percentile_tile_cleanup` 在 Layout 更新后调用 PostHog 官方 `delete_tile` action，只软删除 Dashboard tile。Insight 本身继续纳管并保留，便于回滚；重复执行时没有匹配 tile 就不会产生修改。

清理 Provisioner 在本地运行，依赖 POSIX 兼容 Shell、`curl` 和 `jq`。配置的 Personal API Key 必须可以读取 Overview Dashboard 并调用其 `delete_tile` action。任一依赖缺失或 API 请求失败时，`terraform apply` 会失败，不会静默遗留过时图块。

### 7.1 业务配置

已提交的 `dashboard.tfvars.json` 提供以下模块专属配置：

| 变量 | 当前值 | 用途 |
| --- | --- | --- |
| `dashboard_name` | `Intake Performance Overview` | Overview Dashboard 名称 |
| `diagnostics_dashboard_name` | `Intake Performance Diagnostics` | Diagnostics Dashboard 名称 |
| `dashboard_description` | 空 | Overview 可选描述 |
| `dashboard_pinned` | `false` | Overview Pinned 状态 |
| `dashboard_tags` | `[]` | 两个 Dashboard 共用的标签 |
| `date_from` | `-24h` | Overview HogQL、P75、Coverage 和 PV/UV 滚动时间范围 |
| `web_vitals_trend_date_from` | `-1h` | Dashboard 覆盖前，Overview 比例 Trends 卡保存的滚动时间范围 |
| `diagnostics_date_from` | `-7d` | Diagnostics 滚动时间范围 |
| `intake_path` | `/intake` | 性能查询使用的 cleaned-path 目标 |

共享连接配置仍保存在被忽略的根目录 `terraform.tfvars` 中：`posthog_host`、`posthog_project_id` 以及声明为 Sensitive 和 Ephemeral 的 `posthog_api_key`。有 State 的 Make 命令会自动使用 `project-<posthog_project_id>` Workspace。

### 7.2 输出

执行 `make output-intake-performance` 查看：

| 输出 | 内容 |
| --- | --- |
| `dashboard_id` / `dashboard_url` | Overview Dashboard ID 和 URL |
| `diagnostics_dashboard_id` / `diagnostics_dashboard_url` | Diagnostics Dashboard ID 和 URL |
| `insight_ids` | 全部 31 个已纳管 Insight 的 Key 到 ID 合并映射 |

## 8. 导入既有资源

该目录中的固定导入映射对应 PostHog 项目 `92499` 的两个已有 Dashboard。首次在一个新的本地环境中管理该项目时，必须先创建项目 Workspace 并导入，禁止直接 `apply`，否则 Terraform 会尝试创建副本。导入脚本会拒绝在其他 Project ID 或不匹配的 Workspace 中使用这些固定 ID。

```bash
make init-intake-performance
make workspace-new-intake-performance
make workspace-show-intake-performance
make import-intake-performance
```

导入脚本会把 2 个 Dashboard、31 个既有 Insight 和 2 个 Dashboard Layout 导入到 `project-92499` 的独立 State；重复执行时会跳过已经纳管的资源。当前既有资源 ID 与 Terraform Key 的对应关系如下：

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
| `intake_poor_inp_ratio` | `10794623` |
| `intake_poor_fcp_ratio` | `10794622` |
| `intake_poor_cls_ratio` | `10794625` |
| `intake_web_vitals_coverage` | `10794624` |
| `intake_inp_p90_web_analytics` | `10794932` |
| `intake_lcp_p90_web_analytics` | `10794927` |
| `intake_fcp_p90_web_analytics` | `10794930` |
| `intake_cls_p90_web_analytics` | `10794931` |
| `intake_inp_p99_web_analytics` | `10794934` |
| `intake_lcp_p99_web_analytics` | `10794928` |
| `intake_fcp_p99_web_analytics` | `10794929` |
| `intake_cls_p99_web_analytics` | `10794933` |
| `intake_web_vitals_percentile_status` | `10795642` |
| `intake_dimension_coverage` | `10794610` |
| `intake_tenant_performance` | `10794612` |
| `intake_org_performance` | `10794613` |
| `intake_domain_performance` | `10794611` |
| `intake_web_vitals_reports` | `10795956` |

Layout 的导入 ID 与 Dashboard ID 相同：Overview 为 `1956103`，Diagnostics 为 `1961465`。完成全部导入后执行：

```bash
make plan-intake-performance
```

完成全部导入或部署后，Plan 应显示 `No changes`。后续变更不应意外创建或删除 Dashboard，也不应删除既有 Insight；确认所有更新都经过审查后，才可以执行 `make apply-intake-performance`。
