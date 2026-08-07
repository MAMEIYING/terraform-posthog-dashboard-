# Intake Error Dashboard: Metrics and Usage

> English | [中文](./intake-error.zh.md)

> Last updated: 2026-08-07
>
> PostHog project: `92499`
>
> Dashboard: [Intake Frontend Error](https://us.posthog.com/project/92499/dashboard/1956440)
>
> Primary users: Developers

## 1. Dashboard goals

This dashboard monitors and diagnoses frontend exceptions on the `/intake` page. It helps answer:

- How many frontend errors are occurring now?
- How many Intake sessions are affected by errors?
- Are errors increasing or occurring in concentrated bursts?
- Which issues, exception types, tenants, domains, or browsers contribute most of the errors?
- Are any errors unhandled?
- Can error details, session IDs, and session replays reconstruct what happened?

The dashboard supports this diagnostic path:

```text
Error volume -> error rate -> time trends -> issues/unhandled errors
             -> type/domain/tenant/browser attribution -> error event details
```

## 2. Global scope

Terraform and the PostHog UI currently use these defaults:

| Setting | Current value | Notes |
| --- | --- | --- |
| Date range | Latest day / Last 24 hours | A rolling 24-hour window, not a calendar day |
| Trend interval | `hour` | Trend charts use hourly buckets |
| Intake path | `$pathname` exactly equals `/intake` | Excludes subpaths and fuzzy matches |
| Error event | `$exception` | Data comes from PostHog Error Tracking |
| Tenant property | `tenant_id` | Event property |
| Test-account filtering | Disabled | Queries set `filterTestAccounts = false` |

Terraform fixes the latest-day range and `/intake` condition inside every insight, and trend charts use hourly buckets. The PostHog UI also stores matching top-level defaults. Consequently, an insight still queries only `/intake` even if the top-level path filter is removed in the UI.

Related implementation:

- Shared date and path conditions: [main.tf](../dashboards/intake-error/main.tf#L1)
- Dashboard resource: [main.tf](../dashboards/intake-error/main.tf#L15)
- Dashboard layout: [main.tf](../dashboards/intake-error/main.tf#L463)

## 3. Panel overview

The dashboard currently contains 11 panels in this layout order:

1. `Frontend error count` and `Frontend error rate`
2. `Frontend error trend`
3. `Frontend error rate trend`
4. `Top error issues` and `Unhandled error trend`
5. `Errors by type` and `Errors by domain`
6. `Errors by tenant`
7. `Errors by browser`
8. `Frontend error list`

### 3.1 Frontend error count

**Definition**

```text
COUNT($exception)
WHERE $pathname = '/intake'
```

- Visualization: `BoldNumber` total card.
- Purpose: Quickly assess the current error-event volume.
- Note: Repeated occurrences of the same error in one session are counted separately. The value represents error occurrences, not affected sessions or users.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L22)

### 3.2 Frontend error rate

**Definition**

```text
Unique Intake sessions with an $exception
----------------------------------------- x 100%
Unique $pageview sessions visiting /intake
```

Query formula:

```text
A = unique_session($exception)
B = unique_session($pageview)
Frontend error rate = A / B x 100
```

#### Source of the unique `$pageview` session count

Denominator `B` comes directly from the `$pageview` event series in the same PostHog Trends query:

1. It uses the same date range and dashboard-level filters as the numerator.
2. It retains only `$pageview` events whose `$pathname` exactly equals `/intake`.
3. It uses the `unique_session` aggregation rather than counting pageview events.
4. PostHog deduplicates by valid session identifiers; events without a session ID do not enter the unique-session result.

The denominator therefore means “unique sessions that visited `/intake` within the query range,” not the number of `$pageview` events or users.

#### Latest seven-day validation

Validation date: 2026-08-06. Range: latest seven days with `$pathname = '/intake'`.

| Metric | Result | Conclusion |
| --- | ---: | --- |
| `/intake` `$pageview` event count | 39 | The pageview query path works in the current window |
| Unique `$pageview` sessions (denominator) | 11 | `unique_session($pageview)` produces a non-zero denominator |
| `$exception` event count | 0 | No matching frontend exception occurred in this window |
| Unique `$exception` sessions (numerator) | 0 | No session was affected by an error |
| Frontend error rate | `0 / 11 = 0%` | The rate is 0% because the numerator is zero, not because the denominator is missing or zero |

**Updated validation conclusion:** `$pageview` has been verified as a working denominator for the current error rate. The 39 events were deduplicated into 11 unique sessions, which matches the expected `unique_session` semantics. A single seven-day window proves only that the current query path works; it does not guarantee long-term collection completeness. Continue monitoring coverage for `$session_id`, `$pathname`, `$host`, and `tenant_id`.

- Visualization: Percentage total card with two decimal places.
- Purpose: Measure the proportion of Intake sessions with at least one error without allowing repeated errors in one session to inflate the impact.
- Prerequisite: `$exception` and `$pageview` events must contain consistent, valid properties such as `$session_id` and `$pathname`.
- Boundary: The current implementation divides two independent unique-session sets and does not explicitly calculate the intersection between error sessions and Intake pageview sessions. The sets should largely align under normal collection, but collection gaps may produce an abnormal ratio.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L53)

### 3.3 Frontend error trend

**Definition**

```text
Hourly COUNT($exception)
WHERE $pathname = '/intake'
```

- Visualization: Hourly line chart.
- Purpose: Identify error spikes, duration, and possible release-regression times.
- Note: An error loop can significantly inflate one hour's count. Interpret it together with the error-rate trend.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L98)

### 3.4 Frontend error rate trend

**Definition**

Calculated independently for each hour:

```text
Unique error sessions / unique Intake pageview sessions x 100%
```

- Visualization: Hourly percentage line chart.
- Purpose: Determine whether the affected proportion is worsening over time rather than looking only at error-event volume.
- Note: A session spanning multiple hours may appear in multiple hourly buckets, so hourly values cannot be summed to derive the daily unique-session count.

#### Hover-display capability validation

`Frontend error rate trend` currently shows only the error rate in its hover state. Validation found that adding numerator `A` and denominator `B` directly to the native `TrendsQuery` cannot produce semantically correct hover values:

- Multiple Trends formula series share one `aggregationAxisFormat`.
- With percentage formatting retained, the numerator and denominator are incorrectly displayed as percentages, such as `11%`, instead of `11` sessions.
- Removing percentage formatting displays session counts correctly but removes the `%` format from the error rate.
- The `BoldNumber` card used by `Frontend error rate` has no hoverable data point.
- Although a PostHog `Metric` card includes a sparkline, native Trends disables that visualization when multiple formulas exist, so it cannot show the rate, numerator, and denominator together.

**Current conclusion:** Terraform retains the existing percentage card and percentage trend without adding numerator and denominator formulas that would use incorrect units. If all three values must be available in the hover state, use one of these approaches:

1. Convert the panels to `HogQL + DataVisualization` and assign separate percentage and integer formats to the error rate and session counts. The total card would need to become a compact trend chart with hover support.
2. Retain the total card, convert only the error-rate trend, and add a separate numerator/denominator detail panel.

Confirm whether changing the total-card form is acceptable before implementing either option so hover requirements do not undermine the dashboard's quick-overview experience.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L248)

### 3.5 Top error issues

**Definition**

```text
Split error events by $exception_issue_id
Show the 10 issues with the highest error counts
Group all remaining issues as Other
```

- Visualization: Hourly multi-series line chart.
- Purpose: Identify the PostHog Error Tracking issues contributing the most errors or growing fastest.
- Note: The panel is better suited to observing issue trends than serving as a strict ranking. The legend contains issue IDs only, which limits readability.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L295)

### 3.6 Unhandled error trend

**Definition**

```text
Hourly COUNT($exception)
WHERE $pathname = '/intake'
  AND $exception_handled = false
```

- Visualization: Hourly line chart.
- Purpose: Surface exceptions that the application did not catch or handle. These errors generally have higher diagnostic priority.
- Note: The panel shows an absolute count and does not directly indicate the proportion of all errors that were unhandled.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L334)

### 3.7 Errors by type

**Definition**

```text
Split error events by $exception_types
Show the top 10 types
Group all remaining types as Other
```

- Visualization: Hourly multi-series line chart.
- Purpose: Distinguish exception types such as `Error` and `TypeError` and observe how they change.
- Note: `$exception_types` is an array property, so its labels may be less stable than `$exception_issue_id` and cannot replace the issue dimension.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L131)

### 3.8 Errors by domain

**Definition**

```text
Split error events by $host
Show the top 10 domains
Group all remaining domains as Other
```

- Visualization: Hourly multi-series line chart.
- Purpose: Identify whether errors occur on production, test, or local domains.
- Important limitation: No environment filter currently exists, so development errors from `localhost` also enter the statistics.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L170)

### 3.9 Errors by tenant

**Definition**

```text
Split error events by tenant_id
Show the top 20 tenants
Group all remaining tenants as Other
```

- Visualization: Hourly multi-series line chart.
- Purpose: Determine whether errors disproportionately affect one tenant or a group of tenants.
- Note: A tenant with more error events may simply have more traffic. Evaluate tenant impact together with a tenant error rate or Intake session volume.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L209)

### 3.10 Errors by browser

**Definition**

```text
Split error events by $browser
Show the top 10 browsers
Group all remaining browsers as Other
```

- Visualization: Hourly multi-series line chart.
- Purpose: Identify browser-compatibility problems.
- Note: The current panel splits only by browser name and does not further distinguish browser version, operating system, or device type.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L375)

### 3.11 Frontend error list

**Definition**

- Queries `/intake` `$exception` events from the latest day.
- Sorts by `timestamp DESC`.
- Returns at most the latest 200 rows.
- Supports date-range filtering, property filtering, refresh, and export.

**Fields and purposes**

| Order | Field | Purpose |
| --- | --- | --- |
| 1 | `time` | Time when the error occurred |
| 2 | `tenant_id` | Affected tenant |
| 3 | `domain` | Environment/domain where the error occurred |
| 4 | `exception_level` | Exception severity |
| 5 | `error_type` | First exception type |
| 6 | `error_message` | First exception message |
| 7 | `error_source` | First error source file |
| 8 | `url` | Full page URL |
| 9 | `issue_id` | PostHog Error Tracking issue ID |
| 10 | `session_id` | Session identifier used to associate behavior and replay |
| 11 | `browser` | Browser name |
| 12 | `browser_version` | Browser version |
| 13 | `os` | Operating system |
| 14 | `os_version` | Operating-system version |
| 15 | `device_type` | Device type |
| 16 | `raw_user_agent` | Raw user-agent string |
| 17 | `handled` | Whether the error was handled |
| 18 | `has_recording` | Whether a session replay exists |
| 19 | `intake_form_variant` | Intake form feature-flag variant |
| 20 | `distinct_id` | PostHog user/anonymous identifier |

**Limitations**

- The list shows only the latest 200 rows, not every error in the query range.
- `error_source` uses `$exception_sources[1]`, which is only the first source file and may not be the business root cause.
- `distinct_id` may be an anonymous identifier and must not automatically be treated as a real user ID.
- `url` may contain query parameters such as `productId`; restrict data access appropriately.
- `has_recording` indicates only whether a replay exists. The current table does not generate a direct replay link.

Implementation: [main.tf](../dashboards/intake-error/main.tf#L414)

## 4. Dashboard filter rules

### 4.1 Recommended global filters

The following properties commonly exist on both `$exception` and `$pageview` and are suitable for dashboard-level filtering:

- Date range
- `$pathname`
- `$host`
- `tenant_id`, provided `$pageview` also carries the property reliably

### 4.2 Global filters not recommended for the error rate

The following properties generally exist only on `$exception`:

- `$exception_types`
- `$exception_level`
- `$exception_handled`
- `$exception_issue_id`

If these filters also apply to the error rate's `$pageview` denominator, they may reduce the denominator to zero. To analyze the error rate for a particular exception type, use one of these approaches:

1. Create a dedicated error-rate insight where the exception property applies only to the numerator.
2. Use HogQL to calculate the error-session set and Intake pageview-session set explicitly.

## 5. Exception property coverage analysis

The analyzed `$exception` sample contains 105 top-level properties, grouped below.

| Category | Representative properties | Current usage | Conclusion |
| --- | --- | --- | --- |
| Exception core | `$exception_issue_id`, types, values, handled, level, sources | Used thoroughly | Continue using issue ID as the primary aggregation dimension |
| Page and environment | `$pathname`, `$host`, `$current_url` | Used | Add an explicit `environment` property |
| Tenant and identity | `tenant_id`, `distinct_id`, `$session_id`, `$device_id` | Core fields used | The current window confirms the pageview denominator works; continue monitoring sessions and validate tenant-property coverage |
| Browser and device | Browser, version, OS, device, screen, and viewport | Basic fields used | Add detailed trends when compatibility problems occur |
| Session Replay | `$has_recording`, status, and replay-debug properties | Replay availability used | Debug properties are unsuitable for a permanent dashboard |
| Feature flags | Intake form version and active feature flags | Form version appears only in the list | Suitable for an error-rate breakdown by form version |
| SDK and release | `$lib`, `$lib_version`, collection configuration | Not used in trends | Add application release and Git SHA |
| Geography and time zone | Country, city, time zone, latitude, longitude | Not used | Avoid adding unless a geographic incident occurs |
| Entry and referral | Session entry URL, path, and referrer | Not used | Add entry path to the list when diagnosing flow-transition problems |
| SDK/Replay debugging | `$sdk_debug_*`, recording buffer, and trigger status | Not used | Suitable for focused diagnostics, not a business error dashboard |

## 6. Identified risks

### P0: Development errors contaminate production conclusions

The analyzed event sample came from:

- Domain: `localhost:3001`
- Next.js/Turbopack development static files
- HMR/CSS chunk-related errors
- `$exception_handled = false`

Because no production-environment filter currently exists, these development errors enter every count, rate, trend, and ranking.

**Recommended order of remediation:**

1. Add a consistent `environment` property to all relevant events, such as `production`, `staging`, or `development`.
2. Make the dashboard include only `environment = production` by default.
3. Until the property is available, temporarily exclude `$host = localhost:3001`.

### P0: The pageview denominator works, but property completeness still needs continuous monitoring

Validation over the latest seven days confirmed that the `/intake` `$pageview` query returns 39 events and 11 unique sessions, so the error-rate denominator is not empty. The risk has changed from “unknown denominator source” to “long-term collection and filter-property completeness requires continuous monitoring.”

Continue monitoring whether `$pageview` reliably contains:

- `$session_id`
- `$pathname`
- `$host`
- `tenant_id`

If an event lacks `$session_id`, PostHog's unique-session aggregation excludes it, making the denominator too small. If `tenant_id` exists only on `$exception`, tenant filtering still breaks the error-rate denominator.

### P1: Source resolution failure

The sampled stack frame contains:

```text
resolve_failure: HTTP 407 Proxy Authentication Required
resolved: false
```

This means the sample source file was not resolved to readable source code. Upload source maps in the production build pipeline and attach a release/Git SHA to events so errors can be associated with a specific deployment.

References:

- [PostHog Error Tracking](https://posthog.com/docs/error-tracking)
- [Uploading PostHog source maps](https://posthog.com/docs/error-tracking/upload-source-maps)

### P1: Error-event count alone does not represent impact

An error loop can emit many `$exception` events in one session. During diagnosis, observe all three measures:

1. Error-event count: How many times did errors occur?
2. Affected-session count: How many Intake sessions encountered at least one error?
3. Error rate: What proportion of Intake sessions was affected?

## 7. Optimization roadmap

### P0: Data trustworthiness

1. Add `environment` and include only production by default.
2. Monitor session, path, host, and tenant property coverage on `$pageview`; one seven-day validation cannot replace continuous monitoring.
3. Configure production source-map uploads.
4. Add a `release`, `git_sha`, or application-version property.

### P1: Recommended new or revised panels

| Suggested panel | Recommended definition | Value |
| --- | --- | --- |
| `Affected intake sessions` | Unique sessions with an exception under `/intake` | Avoids amplification from error loops and communicates impact directly |
| `Error rate by form variant` | Error rate split by Intake form feature-flag variant | Identifies whether a form version introduced a regression |
| `Top error issues ranking` | Table or bar chart sorting issue IDs by total error count | Answers more directly which issue is most severe |
| `Unhandled error rate` | Unhandled error count ÷ all error count | Distinguishes increased volume from increased severity |
| `Errors by release` | Split by release/Git SHA | Quickly identifies the deployment that introduced an error |

### P2: Add according to incident type

- Browser and browser version.
- Operating system and device type.
- PostHog SDK `$lib_version`.
- Session entry pathname.
- Country, region, or time zone.
- Error-rate thresholds and unhandled-error alerts.

Do not add every property panel at once. Geographic fields, replay-debug fields, device IDs, IP addresses, and complete feature-flag lists are better suited to focused queries; permanent panels would increase dashboard noise and privacy risk.

## 8. Recommended diagnostic workflow

1. Check `Frontend error count` and `Frontend error rate` to distinguish repeated errors from a broader impact.
2. Check count and error-rate trends to determine start time, peak, and duration.
3. Check `Top error issues` and `Unhandled error trend` to identify the main issue and severity.
4. Use the type, domain, tenant, and browser panels to narrow the affected scope.
5. Inspect messages, sources, URLs, session IDs, and client environments in `Frontend error list`.
6. If `has_recording = true`, open the corresponding session replay to reproduce the user's behavior.
7. Associate the issue with a release, source map, and deployment record to identify the code version that introduced it.

## 9. Terraform management boundaries

- Terraform manages the dashboard, all 11 insights, and the complete layout.
- The dashboard uses the independent `dashboards/intake-error` root module and state. Commands for other dashboards do not modify these resources.
- Run `make plan-intake-error` and `make apply-intake-error` from the project root; do not run `terraform apply` directly in the root.
- `posthog_dashboard_layout` fully controls dashboard tiles.
- Do not add tiles only in the PostHog UI if they must persist; the next Terraform apply may overwrite the layout.
- The current top-level default date range, interval, and path filter are stored in the PostHog UI because the provider does not manage dashboard-level filter fields.
- The saved UI filters currently match the default query ranges inside the Terraform insights.

## 10. Summary

The dashboard already provides comprehensive monitoring and diagnostics for Intake frontend errors. Its 11 panels cover error volume, affected proportion, time trends, issues, severity, business segments, client environments, and event details.

The next phase should prioritize data quality instead of adding many panels:

```text
Isolate the production environment
-> continuously monitor denominator data completeness
-> configure source maps and releases
-> add affected-session count and form-version error rate
-> expand client and geographic dimensions only for real incident scenarios
```
