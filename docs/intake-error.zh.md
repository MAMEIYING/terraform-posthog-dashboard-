# Intake Error Dashboard 指标与使用说明

> [English](./intake-error.md) | 中文

> 最后更新：2026-08-06
>
> PostHog 项目：`92499`
>
> Dashboard：[intake error](https://us.posthog.com/project/92499/dashboard/1956440)
>
> 主要使用者：开发人员

## 1. Dashboard 目标

该 Dashboard 用于监控和定位 `/intake` 页面上的前端异常，覆盖以下问题：

- 当前发生了多少前端错误？
- 有多少 Intake 会话受到错误影响？
- 错误是否正在增长或集中爆发？
- 哪些 Issue、异常类型、租户、Domain 或浏览器贡献了主要错误？
- 是否存在未处理错误？
- 能否通过错误明细、Session ID 和 Session Replay 还原现场？

Dashboard 形成以下排障路径：

```text
错误规模 → 错误率 → 时间趋势 → Issue/未处理错误
        → 类型/Domain/租户/浏览器归因 → 错误事件明细
```

## 2. 全局统计范围

Terraform 和 PostHog UI 当前保持以下默认范围：

| 配置 | 当前值 | 说明 |
| --- | --- | --- |
| 时间范围 | 最近 1 天 / Last 24 hours | 滚动 24 小时，不是自然日 |
| 趋势粒度 | `hour` | 趋势图按小时聚合 |
| Intake 路径 | `$pathname` 精确等于 `/intake` | 不包含子路径或模糊匹配路径 |
| 错误事件 | `$exception` | 数据来自 PostHog Error Tracking |
| 租户属性 | `tenant_id` | 事件属性 |
| 测试账号过滤 | 未启用 | 查询中 `filterTestAccounts = false` |

Terraform 在每个 Insight 内固定了最近一天和 `/intake` 条件；趋势图固定为小时粒度。PostHog UI 顶部也保存了相同的默认筛选。因此即使移除 UI 顶部的 Path 筛选，Insight 自身仍然只查询 `/intake`。

相关实现：

- 通用时间和路径条件：[main.tf](../dashboards/intake-error/main.tf#L1)
- Dashboard 资源：[main.tf](../dashboards/intake-error/main.tf#L15)
- Dashboard 布局：[main.tf](../dashboards/intake-error/main.tf#L463)

## 3. 面板总览

Dashboard 当前包含 11 个面板，布局顺序为：

1. `Frontend error count`、`Frontend error rate`
2. `Frontend error trend`
3. `Frontend error rate trend`
4. `Top error issues`、`Unhandled error trend`
5. `Errors by type`、`Errors by domain`
6. `Errors by tenant`
7. `Errors by browser`
8. `Frontend error list`

### 3.1 Frontend error count

**统计口径**

```text
COUNT($exception)
WHERE $pathname = '/intake'
```

- 展示方式：总数卡片 `BoldNumber`。
- 作用：快速判断当前错误事件规模。
- 注意：同一会话重复触发同一错误会重复计数。因此它反映错误产生次数，不等于受影响会话数或用户数。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L22)

### 3.2 Frontend error rate

**统计口径**

```text
发生 $exception 的唯一 Intake 会话数
────────────────────────────────── × 100%
访问 /intake 的唯一 $pageview 会话数
```

对应查询公式：

```text
A = unique_session($exception)
B = unique_session($pageview)
Frontend error rate = A / B × 100
```

#### `$pageview` 唯一会话数的来源

分母 `B` 直接来自同一个 PostHog Trends 查询中的 `$pageview` 事件序列：

1. 使用与分子相同的时间范围和 Dashboard 全局筛选。
2. 只保留 `$pathname` 精确等于 `/intake` 的 `$pageview`。
3. 使用 `unique_session` 聚合，而不是统计 Pageview 事件总数。
4. PostHog 按有效 Session 标识去重；没有 Session ID 的事件不会进入唯一会话结果。

因此，分母表达的是“查询范围内访问过 `/intake` 的唯一会话数”，不是 `$pageview` 事件数，也不是用户数。

#### 最近 7 天验证记录

验证时间：2026-08-06；验证范围：最近 7 天，`$pathname = '/intake'`。

| 指标 | 结果 | 结论 |
| --- | ---: | --- |
| `/intake` `$pageview` 事件数 | 39 | 当前窗口的 Pageview 查询链路可用 |
| `$pageview` 唯一会话数（分母） | 11 | `unique_session($pageview)` 能够产生非零分母 |
| `$exception` 事件数 | 0 | 该窗口内没有匹配的前端异常事件 |
| `$exception` 唯一会话数（分子） | 0 | 没有受错误影响的会话 |
| Frontend error rate | `0 ÷ 11 = 0%` | 0% 来自分子为 0，不是分母缺失或除零 |

**更新后的验证结论：** `$pageview` 已验证可以作为当前错误率分母，且事件数 39 被去重为 11 个唯一会话，符合 `unique_session` 的预期语义。但单个 7 天窗口只能证明当前查询链路可用，不能证明长期采集完整性；仍需持续监控 `$session_id`、`$pathname`、`$host` 和 `tenant_id` 的覆盖率。

- 展示方式：百分比总数卡片，保留两位小数。
- 作用：衡量至少发生一次错误的 Intake 会话占比，避免单会话重复报错放大影响范围。
- 前提：`$exception` 和 `$pageview` 必须具有一致且有效的 `$session_id`、`$pathname` 等属性。
- 边界：当前是两个独立唯一会话集合相除，并未显式计算“错误会话与 Intake pageview 会话的交集”。正常采集下两者应基本一致，但采集缺失时可能出现异常比例。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L53)

### 3.3 Frontend error trend

**统计口径**

```text
按小时统计 COUNT($exception)
WHERE $pathname = '/intake'
```

- 展示方式：小时折线图。
- 作用：识别错误突增、持续时间和可能的发布回归时间点。
- 注意：错误循环可能使某个小时的数量显著放大；需要与错误率趋势结合判断影响范围。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L98)

### 3.4 Frontend error rate trend

**统计口径**

每个小时分别计算：

```text
错误唯一会话数 ÷ Intake pageview 唯一会话数 × 100%
```

- 展示方式：小时百分比折线图。
- 作用：判断错误影响范围是否随时间恶化，而不仅仅观察错误事件数量。
- 注意：一个跨越多个小时的会话可能分别出现在多个小时桶中，因此各小时数据不能简单相加得到全天唯一会话数。

#### Hover 展示能力验证

当前 `Frontend error rate trend` 只在 Hover 中显示错误率。验证发现，直接在原生 `TrendsQuery` 中增加分子 `A` 和分母 `B` 不能得到语义正确的 Hover：

- Trends 的多个公式序列共用一个 `aggregationAxisFormat`。
- 保留百分比格式时，分子和分母会被错误显示成百分比，例如 `11%`，而不是 `11` 个会话。
- 移除百分比格式虽然能正确显示会话数，但错误率会失去 `%` 格式。
- `Frontend error rate` 使用的 `BoldNumber` 大数字卡片没有可悬停的数据点。
- PostHog `Metric` 卡片虽然带 Sparkline，但原生 Trends 在存在多个公式时会禁用该展示类型，因此不能同时呈现错误率、分子和分母。

**当前结论：** Terraform 仍保留现有百分比卡片和百分比趋势图，没有写入会造成单位错误的分子/分母公式。若后续必须在 Hover 中同时显示三项，需要采用以下方案之一：

1. 将相关面板改为 `HogQL + DataVisualization`，为错误率和会话数分别配置百分比、整数格式；大数字卡片需要改成支持 Hover 的紧凑趋势图。
2. 保留大数字卡片，只改造错误率趋势图，并增加独立的分子/分母明细面板。

推荐在确认是否允许改变大数字卡片形态后再实施，避免为满足 Hover 而破坏当前 Dashboard 的快速总览体验。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L248)

### 3.5 Top error issues

**统计口径**

```text
按 $exception_issue_id 拆分错误事件
展示错误数量最高的前 10 个 Issue
其余 Issue 聚合为 Other
```

- 展示方式：按小时的多系列折线图。
- 作用：识别贡献最大或正在增长的 PostHog Error Tracking Issue。
- 注意：当前面板更擅长观察 Issue 趋势，不是严格的数量排行榜；图例只显示 Issue ID，可读性有限。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L295)

### 3.6 Unhandled error trend

**统计口径**

```text
按小时统计 COUNT($exception)
WHERE $pathname = '/intake'
  AND $exception_handled = false
```

- 展示方式：小时折线图。
- 作用：重点发现没有被应用捕获或处理的异常，这类错误通常具有更高排障优先级。
- 注意：当前显示绝对数量，无法直接判断未处理错误占全部错误的比例。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L334)

### 3.7 Errors by type

**统计口径**

```text
按 $exception_types 拆分错误事件
展示前 10 个类型
其余类型聚合为 Other
```

- 展示方式：按小时的多系列折线图。
- 作用：区分 `Error`、`TypeError` 等异常类型及其变化趋势。
- 注意：`$exception_types` 是数组属性，标签可能不如 `$exception_issue_id` 稳定，不能替代 Issue 维度。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L131)

### 3.8 Errors by domain

**统计口径**

```text
按 $host 拆分错误事件
展示前 10 个 Domain
其余 Domain 聚合为 Other
```

- 展示方式：按小时的多系列折线图。
- 作用：识别错误发生在哪些生产、测试或本地域名。
- 重要限制：当前没有环境过滤，`localhost` 开发错误也会进入统计。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L170)

### 3.9 Errors by tenant

**统计口径**

```text
按 tenant_id 拆分错误事件
展示前 20 个租户
其余租户聚合为 Other
```

- 展示方式：按小时的多系列折线图。
- 作用：判断错误是否集中影响某个或一组租户。
- 注意：错误事件数高的租户也可能只是访问量更大。评估租户影响时，应结合“租户错误率”或租户 Intake 会话量。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L209)

### 3.10 Errors by browser

**统计口径**

```text
按 $browser 拆分错误事件
展示前 10 个浏览器
其余浏览器聚合为 Other
```

- 展示方式：按小时的多系列折线图。
- 作用：发现浏览器兼容性问题。
- 注意：当前只按浏览器名称拆分，没有进一步区分浏览器版本、操作系统或设备类型。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L375)

### 3.11 Frontend error list

**统计口径**

- 查询最近一天的 `/intake` `$exception` 事件。
- 按 `timestamp DESC` 排序。
- 最多返回最新 200 条。
- 支持时间范围、属性筛选、刷新和导出。

**字段及作用**

| 顺序 | 字段 | 作用 |
| --- | --- | --- |
| 1 | `time` | 错误发生时间 |
| 2 | `tenant_id` | 受影响租户 |
| 3 | `domain` | 错误发生环境/Domain |
| 4 | `exception_level` | 异常级别 |
| 5 | `error_type` | 首个异常类型 |
| 6 | `error_message` | 首个异常消息 |
| 7 | `error_source` | 首个错误来源文件 |
| 8 | `url` | 完整页面 URL |
| 9 | `issue_id` | PostHog Error Tracking Issue ID |
| 10 | `session_id` | 会话标识，用于关联行为和 Replay |
| 11 | `browser` | 浏览器名称 |
| 12 | `browser_version` | 浏览器版本 |
| 13 | `os` | 操作系统 |
| 14 | `os_version` | 操作系统版本 |
| 15 | `device_type` | 设备类型 |
| 16 | `raw_user_agent` | 原始 User Agent |
| 17 | `handled` | 错误是否已处理 |
| 18 | `has_recording` | 是否存在 Session Replay |
| 19 | `intake_form_variant` | Intake 表单 Feature Flag 版本 |
| 20 | `distinct_id` | PostHog 用户/匿名标识 |

**使用限制**

- 只展示最新 200 条，不代表查询范围内的全部错误。
- `error_source` 取 `$exception_sources[1]`，只是第一个来源文件，不一定是业务根因。
- `distinct_id` 可能是匿名标识，不能直接视为真实用户 ID。
- `url` 可能包含 `productId` 等查询参数，需要限制数据访问权限。
- `has_recording` 只表示 Replay 是否存在，当前没有生成直接 Replay 跳转链接。

实现位置：[main.tf](../dashboards/intake-error/main.tf#L414)

## 4. Dashboard 筛选规则

### 4.1 推荐使用的全局筛选

以下属性通常同时存在于 `$exception` 和 `$pageview`，适合作为 Dashboard 全局筛选：

- 时间范围
- `$pathname`
- `$host`
- `tenant_id`，前提是 `$pageview` 也稳定携带该属性

### 4.2 不建议直接用于错误率的全局筛选

以下属性通常只存在于 `$exception`：

- `$exception_types`
- `$exception_level`
- `$exception_handled`
- `$exception_issue_id`

如果这些筛选同时作用于错误率的 `$pageview` 分母，可能使分母变成 0。需要分析特定异常类型的错误率时，建议采用以下方式之一：

1. 创建专用错误率 Insight，使异常属性只作用于分子。
2. 使用 HogQL 显式计算错误会话集合和 Intake pageview 会话集合。

## 5. Exception 属性覆盖分析

已分析的 `$exception` 样本包含 105 个顶层属性，可归纳为以下类别。

| 类别 | 代表属性 | 当前使用情况 | 结论 |
| --- | --- | --- | --- |
| 异常核心 | `$exception_issue_id`、`types`、`values`、`handled`、`level`、`sources` | 使用充分 | 继续以 Issue ID 作为主要聚合维度 |
| 页面与环境 | `$pathname`、`$host`、`$current_url` | 已使用 | 需要增加明确的 `environment` 属性 |
| 租户与身份 | `tenant_id`、`distinct_id`、`$session_id`、`$device_id` | 核心字段已使用 | 当前窗口已验证 Pageview 分母可用；仍需持续监控 Session，并验证 Tenant 属性覆盖率 |
| 浏览器与设备 | 浏览器、版本、OS、设备、屏幕和 viewport | 基础字段已使用 | 兼容性问题发生时再增加细分趋势 |
| Session Replay | `$has_recording`、状态和 Replay 调试字段 | 使用是否存在 Replay | 调试属性不适合常驻 Dashboard |
| Feature Flag | Intake 表单版本、活跃 Feature Flags | 表单版本只在列表使用 | 适合增加表单版本错误率 |
| SDK/发布 | `$lib`、`$lib_version`、采集配置 | 未用于趋势 | 建议补充应用 release 和 git SHA |
| Geo/时区 | 国家、城市、时区、经纬度 | 未使用 | 除非出现地域性故障，否则不建议增加 |
| 入口与来源 | Session entry URL、路径、referrer | 未使用 | 流程跳转问题可在列表增加入口路径 |
| SDK/Replay 调试 | `$sdk_debug_*`、录制缓冲区和触发状态 | 未使用 | 适合专项诊断，不适合业务错误 Dashboard |

## 6. 已识别风险

### P0：开发环境错误污染生产结论

已分析的事件样本来自：

- Domain：`localhost:3001`
- Next.js/Turbopack 开发静态文件
- HMR/CSS chunk 相关错误
- `$exception_handled = false`

由于当前没有生产环境筛选，这类开发错误会进入所有数量、错误率、趋势和排行榜。

**推荐处理顺序：**

1. 为所有相关事件增加统一 `environment` 属性，例如 `production`、`staging`、`development`。
2. Dashboard 默认只包含 `environment = production`。
3. 在环境属性补齐前，可临时排除 `$host = localhost:3001`。

### P0：Pageview 分母已验证可用，属性完整性仍需持续监控

最近 7 天验证已确认 `/intake` `$pageview` 查询能够返回 39 个事件和 11 个唯一会话，错误率分母不是空值。当前风险已从“分母来源未知”更新为“需要持续监控长期采集和筛选属性完整性”。

仍需监控 `$pageview` 是否稳定包含：

- `$session_id`
- `$pathname`
- `$host`
- `tenant_id`

如果事件缺少 `$session_id`，PostHog 的唯一会话聚合会排除这些事件，导致分母偏小。如果 `tenant_id` 只存在于 `$exception`，按租户过滤时错误率分母仍会失效。

### P1：源码解析失败

样本 Stack Frame 中包含：

```text
resolve_failure: HTTP 407 Proxy Authentication Required
resolved: false
```

这表示样本来源文件没有解析为可读源码。生产环境应在构建流程中上传 Source Map，并为事件补充 release/git SHA，以便将错误和具体部署关联。

参考资料：

- [PostHog Error Tracking](https://posthog.com/docs/error-tracking)
- [PostHog Source Map 上传](https://posthog.com/docs/error-tracking/upload-source-maps)

### P1：错误事件数不能独立代表影响范围

一个错误循环可能在同一会话中产生大量 `$exception`。排障时应同时观察：

1. 错误事件数：错误产生了多少次。
2. 受影响会话数：多少 Intake 会话至少发生一次错误。
3. 错误率：受影响会话占 Intake 会话的比例。

## 7. 优化路线图

### P0：数据可信度

1. 增加 `environment` 并默认只统计生产环境。
2. 建立 `$pageview` 的 Session、Path、Host 和 Tenant 属性覆盖率监控；最近 7 天的一次性验证不能替代持续监控。
3. 配置生产 Source Map 上传。
4. 增加 `release`、`git_sha` 或应用版本属性。

### P1：建议新增或调整的面板

| 建议面板 | 推荐口径 | 价值 |
| --- | --- | --- |
| `Affected intake sessions` | `/intake` 下发生异常的唯一会话数 | 避免错误循环放大，直接表达影响范围 |
| `Error rate by form variant` | 按 Intake 表单 Feature Flag 版本拆分错误率 | 判断某个表单版本是否引入回归 |
| `Top error issues ranking` | Issue ID 按错误总数降序的表格或柱状图 | 更直接回答哪个 Issue 最严重 |
| `Unhandled error rate` | 未处理错误数 ÷ 全部错误数 | 区分错误规模上涨和严重性上涨 |
| `Errors by release` | 按 release/git SHA 拆分 | 快速定位引入错误的部署版本 |

### P2：按故障类型增加

- Browser + browser version。
- OS / device type。
- PostHog SDK `$lib_version`。
- Session entry pathname。
- 国家、地区或时区。
- 错误率阈值和 Unhandled 错误告警。

不建议一次性增加全部属性面板。Geo、Replay 调试字段、设备 ID、IP 和完整 Feature Flag 列表更适合专项查询，否则会增加 Dashboard 噪声和隐私风险。

## 8. 推荐排障流程

1. 查看 `Frontend error count` 和 `Frontend error rate`，判断是重复报错还是影响范围扩大。
2. 查看数量和错误率趋势，确定开始时间、峰值和持续时间。
3. 查看 `Top error issues` 与 `Unhandled error trend`，确定主要 Issue 和严重性。
4. 使用类型、Domain、租户和浏览器面板缩小影响范围。
5. 在 `Frontend error list` 中查看消息、来源、URL、Session ID 和终端环境。
6. 如果 `has_recording = true`，进入对应 Session Replay 复现用户行为。
7. 将 Issue 与 release、Source Map 和发布记录关联，定位引入问题的代码版本。

## 9. Terraform 管理边界

- Dashboard、11 个 Insight 和完整布局由 Terraform 管理。
- 该 Dashboard 使用 `dashboards/intake-error` 独立根模块和独立 State；其他 Dashboard 的命令不会修改这些资源。
- 从项目根目录使用 `make plan-intake-error` 和 `make apply-intake-error`，不要直接在根目录执行 `terraform apply`。
- `posthog_dashboard_layout` 会完整接管 Dashboard 图块。
- 不要仅在 PostHog UI 添加需要长期保留的图块；下一次 Terraform Apply 可能覆盖布局。
- 当前顶部默认时间、粒度和 Path 筛选保存在 PostHog UI 中，因为当前 Provider 不管理 Dashboard 级筛选字段。
- UI 保存的筛选目前与 Terraform Insight 内的默认查询范围一致。

## 10. 总结

当前 Dashboard 已具备较完整的 Intake 前端错误监控和排障能力，现有 11 个面板覆盖错误规模、影响比例、时间趋势、Issue、严重性、业务分群、客户端环境和事件明细。

下一阶段不建议优先堆叠大量面板。推荐顺序是：

```text
隔离生产环境
→ 持续监控错误率分母的数据完整性
→ 配置 Source Map 和 Release
→ 增加受影响会话数及表单版本错误率
→ 再按真实故障场景扩展客户端和地域维度
```
