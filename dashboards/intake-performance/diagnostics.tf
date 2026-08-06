locals {
  diagnostics_dimensions = {
    tenant = {
      name          = "Tenant"
      property_name = "tenant_id"
      property_expr = "properties.tenant_id"
      layout        = { x = 0, y = 16, w = 12, h = 6 }
    }
    org = {
      name          = "Organization"
      property_name = "org_id"
      property_expr = "properties.org_id"
      layout        = { x = 0, y = 22, w = 12, h = 6 }
    }
    domain = {
      name          = "Domain"
      property_name = "$host"
      property_expr = "properties.$host"
      layout        = { x = 0, y = 28, w = 12, h = 6 }
    }
  }

  diagnostics_dimension_insights = {
    for key, dimension in local.diagnostics_dimensions : "intake_${key}_performance" => {
      name        = "Intake performance by ${dimension.name}"
      description = "Deduplicated Web Vitals by $pageview_id. Missing ${dimension.property_name} values remain visible in the (missing) bucket."
      layout      = dimension.layout
      query = {
        kind = "DataVisualizationNode"
        source = {
          kind = "HogQLQuery"
          filters = {
            dateRange          = local.diagnostics_date_range
            filterTestAccounts = false
            properties         = [local.cleaned_path_filter]
          }
          query = trimspace(<<-HOGQL
            WITH raw AS (
                SELECT
                    timestamp,
                    properties.$pageview_id AS pageview_id,
                    if(${dimension.property_expr} IS NULL OR toString(${dimension.property_expr}) = '',
                       NULL, toString(${dimension.property_expr})) AS dimension_value,
                    if(properties.$web_vitals_LCP_value IS NULL, NULL,
                       toFloat(properties.$web_vitals_LCP_value)) AS lcp,
                    if(properties.$web_vitals_INP_value IS NULL, NULL,
                       toFloat(properties.$web_vitals_INP_value)) AS inp,
                    if(properties.$web_vitals_FCP_value IS NULL, NULL,
                       toFloat(properties.$web_vitals_FCP_value)) AS fcp,
                    if(properties.$web_vitals_CLS_value IS NULL, NULL,
                       toFloat(properties.$web_vitals_CLS_value)) AS cls
                FROM events
                WHERE event = '$web_vitals'
                  AND properties.$pageview_id IS NOT NULL
                  AND timestamp <= now()
                  AND {filters}
            ),
            pageviews AS (
                SELECT
                    pageview_id,
                    if(countIf(dimension_value IS NOT NULL) = 0, '(missing)',
                       argMaxIf(dimension_value, timestamp, dimension_value IS NOT NULL)) AS dimension_value,
                    if(countIf(lcp IS NOT NULL) = 0, NULL,
                       argMaxIf(lcp, timestamp, lcp IS NOT NULL)) AS lcp,
                    if(countIf(inp IS NOT NULL) = 0, NULL,
                       argMaxIf(inp, timestamp, inp IS NOT NULL)) AS inp,
                    if(countIf(fcp IS NOT NULL) = 0, NULL,
                       argMaxIf(fcp, timestamp, fcp IS NOT NULL)) AS fcp,
                    if(countIf(cls IS NOT NULL) = 0, NULL,
                       argMaxIf(cls, timestamp, cls IS NOT NULL)) AS cls
                FROM raw
                GROUP BY pageview_id
            )
            SELECT
                dimension_value AS ${key},
                count() AS vitals_pageviews,
                countIf(lcp IS NOT NULL) AS lcp_samples,
                round(quantileIf(0.75)(lcp, lcp IS NOT NULL), 0) AS lcp_p75_ms,
                round(100.0 * countIf(lcp > 4000) / nullIf(countIf(lcp IS NOT NULL), 0), 1) AS poor_lcp_percent,
                countIf(inp IS NOT NULL) AS inp_samples,
                round(quantileIf(0.75)(inp, inp IS NOT NULL), 0) AS inp_p75_ms,
                round(100.0 * countIf(inp > 500) / nullIf(countIf(inp IS NOT NULL), 0), 1) AS poor_inp_percent,
                countIf(fcp IS NOT NULL) AS fcp_samples,
                round(quantileIf(0.75)(fcp, fcp IS NOT NULL), 0) AS fcp_p75_ms,
                round(100.0 * countIf(fcp > 3000) / nullIf(countIf(fcp IS NOT NULL), 0), 1) AS poor_fcp_percent,
                countIf(cls IS NOT NULL) AS cls_samples,
                round(quantileIf(0.75)(cls, cls IS NOT NULL), 3) AS cls_p75,
                round(100.0 * countIf(cls > 0.25) / nullIf(countIf(cls IS NOT NULL), 0), 1) AS poor_cls_percent
            FROM pageviews
            GROUP BY dimension_value
            ORDER BY vitals_pageviews DESC
            LIMIT 50
          HOGQL
          )
        }
        display = "ActionsTable"
        tableSettings = {
          columns = [
            { column = key, settings = {} },
            { column = "vitals_pageviews", settings = {} },
            { column = "lcp_samples", settings = {} },
            { column = "lcp_p75_ms", settings = {} },
            { column = "poor_lcp_percent", settings = { formatting = { suffix = "%" } } },
            { column = "inp_samples", settings = {} },
            { column = "inp_p75_ms", settings = {} },
            { column = "poor_inp_percent", settings = { formatting = { suffix = "%" } } },
            { column = "fcp_samples", settings = {} },
            { column = "fcp_p75_ms", settings = {} },
            { column = "poor_fcp_percent", settings = { formatting = { suffix = "%" } } },
            { column = "cls_samples", settings = {} },
            { column = "cls_p75", settings = {} },
            { column = "poor_cls_percent", settings = { formatting = { suffix = "%" } } },
          ]
        }
      }
    }
  }

  diagnostics_insights = merge(
    {
      intake_dimension_coverage = {
        name        = "Intake dimension coverage"
        description = "Coverage of tenant_id, org_id, and $host across deduplicated Web Vitals pageviews."
        layout      = { x = 0, y = 12, w = 12, h = 4 }
        query = {
          kind = "DataVisualizationNode"
          source = {
            kind = "HogQLQuery"
            filters = {
              dateRange          = local.diagnostics_date_range
              filterTestAccounts = false
              properties         = [local.cleaned_path_filter]
            }
            query = trimspace(<<-HOGQL
              WITH raw AS (
                  SELECT
                      timestamp,
                      properties.$pageview_id AS pageview_id,
                      if(properties.tenant_id IS NULL OR toString(properties.tenant_id) = '',
                         NULL, toString(properties.tenant_id)) AS tenant_id,
                      if(properties.org_id IS NULL OR toString(properties.org_id) = '',
                         NULL, toString(properties.org_id)) AS org_id,
                      if(properties.$host IS NULL OR toString(properties.$host) = '',
                         NULL, toString(properties.$host)) AS domain
                  FROM events
                  WHERE event = '$web_vitals'
                    AND properties.$pageview_id IS NOT NULL
                    AND timestamp <= now()
                    AND {filters}
              ),
              pageviews AS (
                  SELECT
                      pageview_id,
                      if(countIf(tenant_id IS NOT NULL) = 0, NULL,
                         argMaxIf(tenant_id, timestamp, tenant_id IS NOT NULL)) AS tenant_id,
                      if(countIf(org_id IS NOT NULL) = 0, NULL,
                         argMaxIf(org_id, timestamp, org_id IS NOT NULL)) AS org_id,
                      if(countIf(domain IS NOT NULL) = 0, NULL,
                         argMaxIf(domain, timestamp, domain IS NOT NULL)) AS domain
                  FROM raw
                  GROUP BY pageview_id
              )
              SELECT dimension, covered_pageviews, total_pageviews, distinct_values,
                     round(100.0 * covered_pageviews / nullIf(total_pageviews, 0), 1) AS coverage_percent
              FROM (
                  SELECT 1 AS dimension_order, 'tenant_id' AS dimension,
                         countIf(tenant_id IS NOT NULL) AS covered_pageviews,
                         count() AS total_pageviews,
                         uniqIf(tenant_id, tenant_id IS NOT NULL) AS distinct_values
                  FROM pageviews
                  UNION ALL
                  SELECT 2, 'org_id', countIf(org_id IS NOT NULL), count(),
                         uniqIf(org_id, org_id IS NOT NULL)
                  FROM pageviews
                  UNION ALL
                  SELECT 3, '$host', countIf(domain IS NOT NULL), count(),
                         uniqIf(domain, domain IS NOT NULL)
                  FROM pageviews
              )
              ORDER BY dimension_order
            HOGQL
            )
          }
          display = "ActionsTable"
          tableSettings = {
            columns = [
              { column = "dimension", settings = {} },
              { column = "covered_pageviews", settings = {} },
              { column = "total_pageviews", settings = {} },
              { column = "distinct_values", settings = {} },
              {
                column = "coverage_percent"
                settings = {
                  formatting = {
                    suffix = "%"
                  }
                }
              },
            ]
          }
        }
      }
      intake_web_vitals_reports = {
        name        = "Intake Web Vitals reports"
        description = "One row per Web Vitals report, ordered newest first. PostHog loads 100 rows initially and exposes more rows through the table's load-more control."
        layout      = { x = 0, y = 34, w = 12, h = 8 }
        query = {
          kind = "DataVisualizationNode"
          source = {
            kind = "HogQLQuery"
            filters = {
              dateRange          = local.diagnostics_date_range
              filterTestAccounts = false
              properties         = [local.cleaned_path_filter]
            }
            query = trimspace(<<-HOGQL
              SELECT
                  timestamp AS reported_at,
                  if(properties.$web_vitals_LCP_value IS NULL, NULL,
                     round(toFloat(properties.$web_vitals_LCP_value), 0)) AS lcp_ms,
                  if(properties.$web_vitals_INP_value IS NULL, NULL,
                     round(toFloat(properties.$web_vitals_INP_value), 0)) AS inp_ms,
                  if(properties.$web_vitals_FCP_value IS NULL, NULL,
                     round(toFloat(properties.$web_vitals_FCP_value), 0)) AS fcp_ms,
                  if(properties.$web_vitals_CLS_value IS NULL, NULL,
                     round(toFloat(properties.$web_vitals_CLS_value), 3)) AS cls,
                  properties.tenant_id AS tenant_id,
                  properties.org_id AS org_id,
                  properties.program_id AS program_id,
                  properties.intake_type AS intake_type,
                  properties.df_experiment_variant AS experiment_variant,
                  properties.intake_version_number AS intake_version,
                  properties.$host AS host,
                  properties.$pathname AS pathname,
                  properties.$current_url AS current_url,
                  properties.$device_type AS device_type,
                  properties.$browser AS browser,
                  properties.$os AS os,
                  properties.$session_id AS session_id,
                  properties.$pageview_id AS pageview_id
              FROM events
              WHERE event = '$web_vitals'
                AND timestamp <= now()
                AND {filters}
              -- Keep this query unbounded so PostHog returns hasMore=true after
              -- the default 100-row page and the table can load subsequent rows.
              ORDER BY timestamp DESC
            HOGQL
            )
          }
          display = "ActionsTable"
          tableSettings = {
            columns = [
              { column = "reported_at", settings = { display = { label = "Reported at" } } },
              { column = "lcp_ms", settings = { display = { label = "LCP (ms)" } } },
              { column = "inp_ms", settings = { display = { label = "INP (ms)" } } },
              { column = "fcp_ms", settings = { display = { label = "FCP (ms)" } } },
              { column = "cls", settings = { display = { label = "CLS" } } },
              { column = "tenant_id", settings = { display = { label = "Tenant" } } },
              { column = "org_id", settings = { display = { label = "Organization" } } },
              { column = "program_id", settings = { display = { label = "Program" } } },
              { column = "intake_type", settings = { display = { label = "Intake type" } } },
              { column = "experiment_variant", settings = { display = { label = "Experiment variant" } } },
              { column = "intake_version", settings = { display = { label = "Intake version" } } },
              { column = "host", settings = { display = { label = "Host" } } },
              { column = "pathname", settings = { display = { label = "Pathname" } } },
              { column = "current_url", settings = { display = { label = "Current URL" } } },
              { column = "device_type", settings = { display = { label = "Device" } } },
              { column = "browser", settings = { display = { label = "Browser" } } },
              { column = "os", settings = { display = { label = "OS" } } },
              { column = "session_id", settings = { display = { label = "Session ID" } } },
              { column = "pageview_id", settings = { display = { label = "Pageview ID" } } },
            ]
          }
        }
      }
    },
    local.diagnostics_dimension_insights,
  )

  diagnostics_insight_order = [
    "intake_dimension_coverage",
    "intake_tenant_performance",
    "intake_org_performance",
    "intake_domain_performance",
    "intake_web_vitals_reports",
  ]
}

resource "posthog_dashboard" "intake_performance_diagnostics" {
  name        = var.diagnostics_dashboard_name
  description = "Seven-day Web Vitals diagnostics by tenant, organization, and domain. Missing dimensions remain visible for data-quality tracking."
  pinned      = false
  tags        = length(var.dashboard_tags) == 0 ? null : var.dashboard_tags
}

resource "posthog_insight" "intake_performance_diagnostics" {
  for_each = local.diagnostics_insights

  name          = each.value.name
  description   = each.value.description
  query_json    = jsonencode(each.value.query)
  dashboard_ids = [posthog_dashboard.intake_performance_diagnostics.id]

  depends_on = [posthog_dashboard.intake_performance_diagnostics]
}

resource "posthog_dashboard_layout" "intake_performance_diagnostics" {
  dashboard_id = posthog_dashboard.intake_performance_diagnostics.id

  tiles = concat(
    [
      for key in local.diagnostics_existing_insight_order : {
        insight_id = posthog_insight.intake_performance[key].id
        text_body  = null
        layouts_json = jsonencode({
          sm = merge(
            local.diagnostics_existing_layouts[key],
            { minH = 2, minW = 2 },
          )
        })
      }
    ],
    [
      {
        insight_id = null
        text_body  = "## Diagnostics filters\nUse the dashboard Filter control with `tenant_id`, `org_id`, or `$host`. Tenant and organization coverage is currently incomplete; `(missing)` is intentionally retained. Aggregate tables deduplicate by `$pageview_id`; the final report list keeps one row per `$web_vitals` event."
        layouts_json = jsonencode({
          sm = { x = 0, y = 10, w = 12, h = 2, minH = 2, minW = 2 }
        })
      }
    ],
    [
      for key in local.diagnostics_insight_order : {
        insight_id = posthog_insight.intake_performance_diagnostics[key].id
        text_body  = null
        layouts_json = jsonencode({
          sm = merge(
            local.diagnostics_insights[key].layout,
            { minH = 2, minW = 2 },
          )
        })
      }
    ],
  )

  depends_on = [
    posthog_insight.intake_performance,
    posthog_insight.intake_performance_diagnostics,
  ]
}
