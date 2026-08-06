locals {
  poor_ratio_metrics = {
    inp = {
      name      = "Intake poor INP ratio"
      property  = "$web_vitals_INP_value"
      threshold = "500"
      layout    = { x = 3, y = 0, w = 3, h = 3 }
    }
    fcp = {
      name      = "Intake poor FCP ratio"
      property  = "$web_vitals_FCP_value"
      threshold = "3000"
      layout    = { x = 6, y = 0, w = 3, h = 3 }
    }
    cls = {
      name      = "Intake poor CLS ratio"
      property  = "$web_vitals_CLS_value"
      threshold = "0.25"
      layout    = { x = 9, y = 0, w = 3, h = 3 }
    }
  }

  poor_ratio_insights = {
    for key, metric in local.poor_ratio_metrics : "intake_poor_${key}_ratio" => {
      name        = metric.name
      description = "Percentage of measured page loads whose ${upper(key)} value is in the poor range."
      layout      = metric.layout
      query = {
        kind = "InsightVizNode"
        source = {
          kind               = "TrendsQuery"
          dateRange          = local.web_vitals_trend_date_range
          filterTestAccounts = false
          interval           = "hour"
          properties         = [local.cleaned_path_filter]
          series = [
            {
              kind  = "EventsNode"
              event = "$web_vitals"
              name  = "$web_vitals"
              math  = "total"
              properties = [
                {
                  key      = metric.property
                  operator = "gt"
                  type     = "event"
                  value    = metric.threshold
                }
              ]
            },
            {
              kind  = "EventsNode"
              event = "$web_vitals"
              name  = "$web_vitals"
              math  = "total"
              properties = [
                {
                  key      = metric.property
                  operator = "is_set"
                  type     = "event"
                  value    = "is_set"
                }
              ]
            },
          ]
          tags = {
            productKey = "web_analytics"
          }
          trendsFilter = {
            display                = "BoldNumber"
            aggregationAxisPostfix = "%"
            decimalPlaces          = 1
            formulaNodes = [
              {
                formula     = "A / B * 100"
                custom_name = "Poor ${upper(key)} ratio (%)"
              }
            ]
          }
        }
      }
    }
  }

  overview_quality_insights = merge(
    local.poor_ratio_insights,
    {
      intake_web_vitals_coverage = {
        name        = "Intake Web Vitals coverage"
        description = "Measured pageview coverage for each Web Vital. Missing values are excluded from metric samples."
        layout      = { x = 0, y = 13, w = 12, h = 4 }
        query = {
          kind = "DataVisualizationNode"
          source = {
            kind = "HogQLQuery"
            filters = {
              dateRange          = local.default_date_range
              filterTestAccounts = false
              properties         = [local.cleaned_path_filter]
            }
            query = trimspace(<<-HOGQL
              WITH pageviews AS (
                  SELECT uniq(properties.$pageview_id) AS total_pageviews
                  FROM events
                  WHERE event = '$pageview'
                    AND events.$session_id_uuid IS NOT NULL
                    AND properties.$pageview_id IS NOT NULL
                    AND timestamp <= now()
                    AND {filters}
              ),
              vitals AS (
                  SELECT
                      uniqIf(properties.$pageview_id, properties.$web_vitals_LCP_value IS NOT NULL) AS lcp_pageviews,
                      uniqIf(properties.$pageview_id, properties.$web_vitals_INP_value IS NOT NULL) AS inp_pageviews,
                      uniqIf(properties.$pageview_id, properties.$web_vitals_FCP_value IS NOT NULL) AS fcp_pageviews,
                      uniqIf(properties.$pageview_id, properties.$web_vitals_CLS_value IS NOT NULL) AS cls_pageviews
                  FROM events
                  WHERE event = '$web_vitals'
                    AND properties.$pageview_id IS NOT NULL
                    AND timestamp <= now()
                    AND {filters}
              )
              SELECT metric, measured_pageviews, total_pageviews,
                     round(100.0 * measured_pageviews / nullIf(total_pageviews, 0), 1) AS coverage_percent
              FROM (
                  SELECT 1 AS metric_order, 'LCP' AS metric, lcp_pageviews AS measured_pageviews,
                         (SELECT total_pageviews FROM pageviews) AS total_pageviews
                  FROM vitals
                  UNION ALL
                  SELECT 2, 'INP', inp_pageviews, (SELECT total_pageviews FROM pageviews)
                  FROM vitals
                  UNION ALL
                  SELECT 3, 'FCP', fcp_pageviews, (SELECT total_pageviews FROM pageviews)
                  FROM vitals
                  UNION ALL
                  SELECT 4, 'CLS', cls_pageviews, (SELECT total_pageviews FROM pageviews)
                  FROM vitals
              )
              ORDER BY metric_order
            HOGQL
            )
          }
          display = "ActionsTable"
          tableSettings = {
            columns = [
              { column = "metric", settings = {} },
              { column = "measured_pageviews", settings = {} },
              { column = "total_pageviews", settings = {} },
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
    },
  )

  overview_quality_order = [
    "intake_poor_inp_ratio",
    "intake_poor_fcp_ratio",
    "intake_poor_cls_ratio",
    "intake_web_vitals_coverage",
  ]
}

resource "posthog_insight" "intake_performance_overview_quality" {
  for_each = local.overview_quality_insights

  name          = each.value.name
  description   = each.value.description
  query_json    = jsonencode(each.value.query)
  dashboard_ids = [posthog_dashboard.intake_performance.id]

  depends_on = [posthog_dashboard.intake_performance]
}
