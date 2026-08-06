locals {
  default_date_range = {
    date_from = var.date_from
  }

  page_trend_date_range = {
    date_from = var.date_from
    date_to   = null
  }

  web_vitals_trend_date_range = {
    date_from    = var.web_vitals_trend_date_from
    date_to      = null
    explicitDate = false
  }

  cleaned_path_filter = {
    key      = "$pathname"
    operator = "is_cleaned_path_exact"
    type     = "event"
    value    = [var.intake_path]
  }

  p75_metrics = {
    inp = {
      name  = "Intake INP P75 (Web Analytics)"
      query = <<-HOGQL
        WITH filtered AS (
            SELECT timestamp, toFloat(properties.$web_vitals_INP_value) AS metric
            FROM events
            WHERE event = '$web_vitals'
              AND {filters}
        ),
        bucketed AS (
            SELECT toStartOfHour(timestamp) AS bucket,
                   quantile(0.75)(metric) AS value
            FROM filtered
            GROUP BY bucket
        )
        SELECT nullIf(argMaxIf(value, bucket, value != 0), 0) AS value
        FROM bucketed
      HOGQL
      formatting = {
        style         = "none"
        prefix        = ""
        suffix        = "ms"
        decimalPlaces = 0
      }
      display = {
        color         = "#1d4aff"
        label         = ""
        trendLine     = false
        displayType   = "auto"
        yAxisPosition = "left"
      }
      layout = { x = 0, y = 3, w = 3, h = 3 }
    }
    lcp = {
      name  = "Intake LCP P75 (Web Analytics)"
      query = <<-HOGQL
        WITH filtered AS (
            SELECT
                timestamp,
                toFloat(properties.$web_vitals_LCP_value) / 1000.0 AS metric
            FROM events
            WHERE event = '$web_vitals'
              AND {filters}
        ),
        bucketed AS (
            SELECT
                toStartOfHour(timestamp) AS bucket,
                quantile(0.75)(metric) AS value
            FROM filtered
            GROUP BY bucket
        )
        SELECT round(nullIf(argMaxIf(value, bucket, value != 0), 0), 2) AS value
        FROM bucketed
      HOGQL
      formatting = {
        prefix = ""
        suffix = "s"
      }
      display = null
      layout  = { x = 3, y = 3, w = 3, h = 3 }
    }
    fcp = {
      name  = "Intake FCP P75 (Web Analytics)"
      query = <<-HOGQL
        WITH filtered AS (
            SELECT timestamp, toFloat(properties.$web_vitals_FCP_value) AS metric
            FROM events
            WHERE event = '$web_vitals'
              AND {filters}
        ),
        bucketed AS (
            SELECT toStartOfHour(timestamp) AS bucket,
                   quantile(0.75)(metric) AS value
            FROM filtered
            GROUP BY bucket
        )
        SELECT round(nullIf(argMaxIf(value, bucket, value != 0), 0), 0) AS value
        FROM bucketed
      HOGQL
      formatting = {
        prefix = ""
        suffix = "ms"
      }
      display = null
      layout  = { x = 6, y = 3, w = 3, h = 3 }
    }
    cls = {
      name  = "Intake CLS P75 (Web Analytics)"
      query = <<-HOGQL
        WITH filtered AS (
            SELECT
                timestamp,
                toFloat(properties.$web_vitals_CLS_value) AS metric
            FROM events
            WHERE event = '$web_vitals'
              AND {filters}
        ),
        bucketed AS (
            SELECT
                toStartOfHour(timestamp) AS bucket,
                quantile(0.75)(metric) AS value
            FROM filtered
            GROUP BY bucket
        )
        SELECT round(if(countIf(value != 0) = 0, NULL, argMax(value, bucket)), 2) AS value
        FROM bucketed
      HOGQL
      formatting = {
        prefix        = ""
        suffix        = ""
        decimalPlaces = 2
      }
      display = null
      layout  = { x = 9, y = 3, w = 3, h = 3 }
    }
  }

  percentile_metrics = {
    inp = {
      name        = "Intake INP P75/P90/P99"
      property    = "$web_vitals_INP_value"
      axis_format = "duration_ms"
      layout      = { x = 0, y = 6, w = 6, h = 5 }
    }
    lcp = {
      name        = "Intake LCP P75/P90/P99"
      property    = "$web_vitals_LCP_value"
      axis_format = "duration_ms"
      layout      = { x = 6, y = 6, w = 6, h = 5 }
    }
    fcp = {
      name        = "Intake FCP P75/P90/P99"
      property    = "$web_vitals_FCP_value"
      axis_format = "duration_ms"
      layout      = { x = 0, y = 11, w = 6, h = 5 }
    }
    cls = {
      name        = "Intake CLS P75/P90/P99"
      property    = "$web_vitals_CLS_value"
      axis_format = null
      layout      = { x = 6, y = 11, w = 6, h = 5 }
    }
  }

  page_totals = {
    pv = {
      name        = "Intake PV total (Web Analytics)"
      aggregation = "count()"
      layout      = { x = 0, y = 16, w = 6, h = 3 }
    }
    uv = {
      name        = "Intake UV total (Web Analytics)"
      aggregation = "uniq(person_id)"
      layout      = { x = 6, y = 16, w = 6, h = 3 }
    }
  }

  page_trends = {
    pv = {
      name        = "Intake PV trend (Web Analytics)"
      custom_name = "Page views"
      math        = "total"
      layout      = { x = 0, y = 19, w = 6, h = 5 }
    }
    uv = {
      name        = "Intake UV trend (Web Analytics)"
      custom_name = "Unique visitors"
      math        = "dau"
      layout      = { x = 6, y = 19, w = 6, h = 5 }
    }
  }

  p75_insights = {
    for key, metric in local.p75_metrics : "intake_${key}_p75_web_analytics" => {
      name        = metric.name
      description = null
      tags        = []
      layout      = metric.layout
      query = {
        kind = "DataVisualizationNode"
        source = {
          kind = "HogQLQuery"
          filters = {
            dateRange          = local.default_date_range
            filterTestAccounts = false
            properties         = [local.cleaned_path_filter]
          }
          query = trimspace(metric.query)
        }
        display = "BoldNumber"
        chartSettings = {
          yAxis = [
            {
              column = "value"
              settings = merge(
                { formatting = metric.formatting },
                metric.display == null ? {} : { display = metric.display },
              )
            }
          ]
        }
        tableSettings = {
          columns = [
            {
              column = "value"
              settings = merge(
                { formatting = metric.formatting },
                metric.display == null ? {} : { display = metric.display },
              )
            }
          ]
        }
      }
    }
  }

  percentile_insights = {
    for key, metric in local.percentile_metrics : "intake_${key}_p75_p90_p99" => {
      name        = metric.name
      description = null
      tags        = []
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
            for percentile in [75, 90, 99] : {
              kind               = "EventsNode"
              event              = "$web_vitals"
              name               = "$web_vitals"
              math               = "p${percentile}"
              math_property      = metric.property
              math_property_type = "numerical_event_properties"
              custom_name        = "P${percentile}"
            }
          ]
          tags = {
            productKey = "web_analytics"
          }
          trendsFilter = merge(
            {
              display    = "ActionsLineGraph"
              showLegend = true
            },
            metric.axis_format == null ? {} : { aggregationAxisFormat = metric.axis_format },
          )
        }
      }
    }
  }

  page_total_insights = {
    for key, metric in local.page_totals : "intake_${key}_total_web_analytics" => {
      name        = metric.name
      description = null
      tags        = []
      layout      = metric.layout
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
            SELECT ${metric.aggregation} AS value
            FROM events
            WHERE event = '$pageview'
              AND events.$session_id_uuid IS NOT NULL
              AND {filters}
          HOGQL
          )
        }
        display = "BoldNumber"
        chartSettings = {
          yAxis = [
            {
              column = "value"
              settings = {
                formatting = {
                  prefix = ""
                  suffix = ""
                }
              }
            }
          ]
        }
        tableSettings = {
          columns = [
            {
              column = "value"
              settings = {
                formatting = {
                  prefix = ""
                  suffix = ""
                }
              }
            }
          ]
        }
      }
    }
  }

  page_trend_insights = {
    for key, metric in local.page_trends : "intake_${key}_trend_web_analytics" => {
      name        = metric.name
      description = null
      tags        = []
      layout      = metric.layout
      query = {
        kind = "InsightVizNode"
        source = {
          kind               = "TrendsQuery"
          dateRange          = local.page_trend_date_range
          filterTestAccounts = false
          interval           = "hour"
          compareFilter = {
            compare = true
          }
          conversionGoal = null
          properties     = [local.cleaned_path_filter]
          series = [
            {
              kind        = "EventsNode"
              event       = "$pageview"
              name        = "Pageview"
              math        = metric.math
              custom_name = metric.custom_name
            }
          ]
          tags = {
            productKey = "web_analytics"
          }
          trendsFilter = {
            display = "ActionsLineGraph"
          }
        }
        hideTooltipOnScroll = true
      }
    }
  }

  insights = merge(
    {
      derived_intake_lcp_slow_load_ratio = {
        name        = "Derived - Intake LCP slow-load ratio"
        description = null
        tags        = []
        layout      = { x = 0, y = 0, w = 12, h = 3 }
        query = {
          kind = "InsightVizNode"
          source = {
            kind      = "TrendsQuery"
            dateRange = local.web_vitals_trend_date_range
            interval  = "minute"
            properties = {
              type = "AND"
              values = [
                {
                  type = "AND"
                  values = [
                    {
                      key      = "$pathname"
                      operator = "exact"
                      type     = "event"
                      value    = [var.intake_path]
                    }
                  ]
                }
              ]
            }
            series = [
              {
                kind  = "EventsNode"
                event = "$web_vitals"
                name  = "$web_vitals"
                math  = "total"
                properties = [
                  {
                    key      = "$web_vitals_LCP_value"
                    operator = "gt"
                    type     = "event"
                    value    = "4000"
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
                    key      = "$web_vitals_LCP_value"
                    operator = "is_set"
                    type     = "event"
                    value    = "is_set"
                  }
                ]
              },
            ]
            tags = {
              productKey = "product_analytics"
            }
            trendsFilter = {
              display                = "BoldNumber"
              aggregationAxisPostfix = "%"
              formulaNodes = [
                {
                  formula     = "A / B * 100"
                  custom_name = "Slow LCP ratio (%)"
                }
              ]
            }
          }
        }
      }
    },
    local.p75_insights,
    local.percentile_insights,
    local.page_total_insights,
    local.page_trend_insights,
  )

  insight_order = [
    "derived_intake_lcp_slow_load_ratio",
    "intake_inp_p75_web_analytics",
    "intake_lcp_p75_web_analytics",
    "intake_fcp_p75_web_analytics",
    "intake_cls_p75_web_analytics",
    "intake_inp_p75_p90_p99",
    "intake_lcp_p75_p90_p99",
    "intake_fcp_p75_p90_p99",
    "intake_cls_p75_p90_p99",
    "intake_pv_total_web_analytics",
    "intake_uv_total_web_analytics",
    "intake_pv_trend_web_analytics",
    "intake_uv_trend_web_analytics",
  ]

  tile_ids = {
    derived_intake_lcp_slow_load_ratio = 10483504
    intake_inp_p75_web_analytics       = 10523813
    intake_lcp_p75_web_analytics       = 10523919
    intake_fcp_p75_web_analytics       = 10524055
    intake_cls_p75_web_analytics       = 10524137
    intake_inp_p75_p90_p99             = 10483345
    intake_lcp_p75_p90_p99             = 10483329
    intake_fcp_p75_p90_p99             = 10483330
    intake_cls_p75_p90_p99             = 10483347
    intake_pv_total_web_analytics      = 10525141
    intake_uv_total_web_analytics      = 10525024
    intake_pv_trend_web_analytics      = 10524613
    intake_uv_trend_web_analytics      = 10524502
  }
}

resource "posthog_dashboard" "intake_performance" {
  name        = var.dashboard_name
  description = var.dashboard_description == "" ? null : var.dashboard_description
  pinned      = var.dashboard_pinned
  tags        = length(var.dashboard_tags) == 0 ? null : var.dashboard_tags
}

resource "posthog_insight" "intake_performance" {
  for_each = local.insights

  name          = each.value.name
  description   = each.value.description
  query_json    = jsonencode(each.value.query)
  tags          = length(each.value.tags) == 0 ? null : each.value.tags
  dashboard_ids = [posthog_dashboard.intake_performance.id]

  depends_on = [posthog_dashboard.intake_performance]
}

# This resource authoritatively manages every tile on the dashboard.
resource "posthog_dashboard_layout" "intake_performance" {
  dashboard_id = posthog_dashboard.intake_performance.id

  tiles = [
    for key in local.insight_order : {
      insight_id = posthog_insight.intake_performance[key].id
      layouts_json = jsonencode({
        sm = merge(
          local.insights[key].layout,
          {
            i      = tostring(local.tile_ids[key])
            minH   = 2
            minW   = 2
            moved  = false
            static = false
          },
        )
      })
    }
  ]

  depends_on = [posthog_insight.intake_performance]
}
