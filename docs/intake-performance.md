# Intake Performance Dashboards: Metrics and Usage

> English | [中文](./intake-performance.zh.md)

> Last synchronized: 2026-08-06
>
> PostHog project: `92499`
>
> Overview: [Intake Performance Overview](https://us.posthog.com/project/92499/dashboard/1956103)
>
> Diagnostics: [Intake Performance Diagnostics](https://us.posthog.com/project/92499/dashboard/1961465)

## 1. Dashboard goals

The two dashboards provide complementary views of `/intake` performance:

- Overview monitors health over the latest 24 hours with Web Vitals P75 trends, poor ratios, metric coverage, and PV/UV.
- Diagnostics supports investigation over the latest 7 days with P75/P90/P99 trends, Tenant/Organization/Domain breakdowns, and an event-level Web Vitals report list.

## 2. Global scope

| Setting | Current value | Notes |
| --- | --- | --- |
| Overview | Latest 24 hours | P75 trends, Coverage, and PV/UV persist `-24h`; the four ratio cards persist `-1h`. The dashboard-level range overrides native Trends cards |
| Diagnostics | Latest 7 days | Percentile trends, dimension tables, and the report list persist `-7d` |
| Trend interval | Overview follows the top-level selection | P75 trends persist `hour` but accept the dashboard `grouped by` override; Diagnostics persists `hour` |
| Page path | `/intake` | All panels except the Derived panel use the Web Analytics cleaned-path definition |
| Comparison | Previous period | PV/UV trends enable period comparison |
| Test-account filtering | Disabled | Trends queries set `filterTestAccounts = false` |

## 3. Overview panels

| Order | Panel | Definition | Layout |
| ---: | --- | --- | --- |
| 1–4 | Derived LCP slow-load ratio, plus INP/FCP/CLS poor ratio | Events above the Poor threshold divided by events where the metric is set; thresholds are LCP 4000 ms, INP 500 ms, FCP 3000 ms, and CLS 0.25. LCP retains the legacy Derived exact-path query; the other three use the Web Analytics cleaned-path definition | Four equal-width bold-number cards |
| 5–8 | INP/LCP/FCP/CLS P75 trend | Uses the same native Trends P75 series as Web Analytics; both the date range and interval accept dashboard-level overrides | 2 × 2 trend charts |
| 9 | Web Vitals coverage | Shows measured pageviews, total pageviews, and coverage for each metric | Full-width table |
| 10–11 | PV/UV total | Counts only valid sessions no later than the current time; PV uses `count()` and UV uses `uniq(person_id)` | Two equal-width bold-number cards |
| 12–13 | PV/UV trend | Shows the current and previous periods using the dashboard-level interval | Two equal-width trend charts |

Overview retains four native P75 trend charts so changing the date range or `grouped by` selection cannot leave the display pinned to the same final hourly bucket. The eight former P90/P99 single-value insights and the status matrix remain managed by Terraform but are detached from Overview for rollback.

## 4. Diagnostics panels

| Order | Panel | Definition | Layout |
| ---: | --- | --- | --- |
| 1–4 | INP/LCP/FCP/CLS P75/P90/P99 | Shows three percentile trends by hour for the latest 7 days | 2 × 2 trend charts |
| 5 | Diagnostics filters | Explains how to use Dashboard Filter with `tenant_id`, `org_id`, and `$host` | Text panel |
| 6 | Dimension coverage | Shows Tenant, Org, and Domain coverage and distinct-value counts after deduplicating by `$pageview_id` | Full-width table |
| 7–9 | Tenant/Organization/Domain performance | Shows valid pageviews, samples, P75, and poor ratio for four metrics per dimension; missing values remain in `(missing)` | Three full-width tables |
| 10 | Web Vitals reports | Keeps one row per `$web_vitals` report and shows key performance, business, experiment, page, device, and session attributes in descending timestamp order | Full-width table |

The dimension tables aggregate by `$pageview_id`. When a pageview reports the same metric more than once, the latest valid value is used so duplicate events do not distort dimension rankings.

The Web Vitals report list does not deduplicate pageviews or hard-code a HogQL `LIMIT`. PostHog returns the first 100 rows by default; when more data exists, the response contains `hasMore = true` and the table can fetch subsequent rows through “Load more.” Its columns are Reported at, LCP, INP, FCP, CLS, Tenant, Organization, Program, Intake type, Experiment variant, Intake version, Host, Pathname, Current URL, Device, Browser, OS, Session ID, and Pageview ID. It inherits the Diagnostics date range, `/intake` cleaned-path condition, and Dashboard Filter.

## 5. Data quality and query semantics

Event audit results from 2026-08-06:

| Event sample | Tenant coverage | Org coverage | Domain coverage | Notes |
| --- | ---: | ---: | ---: | --- |
| 63 `$pageview` events | 1/63 | 1/63 | 63/63 | Tenant/Org are not registered reliably before automatic pageviews |
| 20 sampled `$web_vitals` events | 1/20 | 1/20 | 20/20 | The small sample is affected by API result ordering and only demonstrates missing properties |
| Diagnostics, 7 days, 245 deduplicated pageviews | 245/245 | 200/245 | 245/245 | Actual dashboard aggregation; missing Org values remain in `(missing)` |

Tenant/Org filters are currently suitable for Web Vitals diagnostics but should not be used to explain overall PV/UV. To make top-level Tenant/Org filters cover traffic metrics, the frontend must register `tenant_id` and `org_id` before `$pageview` is generated, or emit a pageview containing both properties.

Coverage is computed independently for each metric because a `$web_vitals` event may contain only a subset of metrics. Missing metrics must not be interpreted as zero.

## 6. Web Analytics alignment

Except for `Derived - Intake LCP slow-load ratio`, all panels use PostHog Web Analytics as the source of truth:

- Web Vitals use `$web_vitals`, the Web Analytics cleaned path, and the corresponding numeric properties for P75/P90/P99.
- Overview P75 uses native TrendsQuery series with the same `$web_vitals` P75 definitions as Web Analytics and accepts dashboard-level date-range and interval overrides.
- PV/UV totals include only `$pageview` events where PostHog resolved `$session_id_uuid`; PV counts events and UV uses the Web Overview-compatible `uniq(person_id)` aggregation.
- PV/UV trends use the native Web Analytics Trends query shape, cleaned path, and current-versus-previous-period comparison.

Dashboard-level property filters are managed in the PostHog UI because the provider cannot declare them. Use Filter with `tenant_id`, `org_id`, or `$host`; all HogQL tables accept those conditions through `{filters}`.

## 7. Terraform management scope

`dashboards/intake-performance` manages:

- Overview Dashboard `1956103` and Diagnostics Dashboard `1961465`.
- Names, descriptions, tags, queries, and visualization settings for 31 insights.
- 13 Overview insight tiles, plus 9 Diagnostics insight tiles and one Diagnostics text tile.

PostHog Provider `1.0.x` does not expose dashboard folders or top-level global filters. Terraform therefore does not manage the `Unfiled/Dashboards` folder, the saved `-24h` dashboard range, or the `hour` interval. Terraform preserves the values stored on each insight. The current 24-hour/hour Web Vitals view still depends on top-level dashboard filters, which should not be removed or overwritten in the PostHog UI.

Both `posthog_dashboard_layout` resources fully own their dashboard tiles. Do not manually add tiles in PostHog that need to persist but are not declared in Terraform.

PostHog Provider `1.0.x` cannot remove a corresponding tile by updating an existing insight's `dashboard_ids` to an empty collection, and the layout resource does not delete existing tiles that are omitted from its declaration. The eight standalone P90/P99 Overview insights and the former status matrix therefore ignore that field through Lifecycle. After the layout update, `terraform_data.intake_performance_overview_percentile_tile_cleanup` calls PostHog's official `delete_tile` action to soft-delete only their dashboard tiles. The insights remain managed and available for rollback; repeated runs make no changes when no matching tile exists.

The cleanup provisioner runs locally and requires a POSIX-compatible shell, `curl`, and `jq`. The configured Personal API Key must be able to read the Overview dashboard and call its `delete_tile` action. If a dependency is missing or the API request fails, `terraform apply` fails instead of silently leaving obsolete tiles behind.

### 7.1 Business configuration

The committed `dashboard.tfvars.json` provides these module-specific values:

| Variable | Current value | Purpose |
| --- | --- | --- |
| `dashboard_name` | `Intake Performance Overview` | Overview dashboard name |
| `diagnostics_dashboard_name` | `Intake Performance Diagnostics` | Diagnostics dashboard name |
| `dashboard_description` | Empty | Optional Overview description |
| `dashboard_pinned` | `false` | Overview pinned state |
| `dashboard_tags` | `[]` | Tags shared by both dashboards |
| `date_from` | `-24h` | Overview HogQL, P75, Coverage, and PV/UV rolling range |
| `web_vitals_trend_date_from` | `-1h` | Saved rolling range for the Overview ratio Trends cards before dashboard overrides |
| `diagnostics_date_from` | `-7d` | Diagnostics rolling range |
| `intake_path` | `/intake` | Cleaned-path target used by performance queries |

Shared connection values remain in the ignored root `terraform.tfvars`: `posthog_host`, `posthog_project_id`, and the sensitive, ephemeral `posthog_api_key`. Stateful Make commands automatically use the `project-<posthog_project_id>` workspace.

### 7.2 Outputs

Run `make output-intake-performance` to inspect:

| Output | Contents |
| --- | --- |
| `dashboard_id` / `dashboard_url` | Overview dashboard ID and URL |
| `diagnostics_dashboard_id` / `diagnostics_dashboard_url` | Diagnostics dashboard ID and URL |
| `insight_ids` | Combined key-to-ID map for all 31 managed insights |

## 8. Importing existing resources

The fixed import map for this module corresponds to two existing dashboards in PostHog project `92499`. In a new local environment for that project, create the project workspace and import existing resources before applying so Terraform does not create duplicates. The import script refuses to use these fixed IDs with another Project ID or a mismatched workspace.

```bash
make init-intake-performance
make workspace-new-intake-performance
make workspace-show-intake-performance
make import-intake-performance
```

The import script imports two dashboards, 31 existing insights, and two dashboard layouts into the isolated `project-92499` State. Re-running it skips resources already under management. Existing insight IDs are:

| Terraform key | PostHog Insight ID |
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

Layout import IDs match their dashboard IDs: `1956103` for Overview and `1961465` for Diagnostics. After all imports complete, run:

```bash
make plan-intake-performance
```

After all resources are imported or deployed, the plan should report `No changes`. Future changes must not unexpectedly create or delete a dashboard or delete an existing insight. Run `make apply-intake-performance` only after reviewing every planned update.
