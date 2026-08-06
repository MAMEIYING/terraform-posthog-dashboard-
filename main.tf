locals {
  default_date_range = {
    date_from = "-1d"
    date_to   = null
  }

  intake_path_filter = {
    key      = "$pathname"
    operator = "exact"
    type     = "event"
    value    = var.intake_path
  }
}

resource "posthog_dashboard" "intake_error" {
  name        = var.dashboard_name
  description = "Developer dashboard for frontend errors on the exact intake path. Defaults to the last day."
  pinned      = true
  tags        = var.dashboard_tags
}

resource "posthog_insight" "frontend_error_count" {
  name        = "Frontend error count"
  description = "Total $exception events where $pathname exactly matches ${var.intake_path}."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      trendsFilter = {
        display    = "BoldNumber"
        showLegend = false
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "frontend_error_rate" {
  name        = "Frontend error rate"
  description = "Percentage of intake pageview sessions that contain at least one frontend exception."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "unique_session"
          custom_name = "Sessions with errors"
        },
        {
          kind        = "EventsNode"
          event       = "$pageview"
          math        = "unique_session"
          custom_name = "Intake sessions"
        }
      ]
      trendsFilter = {
        display = "BoldNumber"
        formulaNodes = [
          {
            formula     = "A / B * 100"
            custom_name = "Frontend error rate"
          }
        ]
        aggregationAxisFormat = "percentage"
        decimalPlaces         = 2
        showLegend            = false
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "error_trend" {
  name        = "Frontend error trend"
  description = "Hourly frontend exception volume for the intake page."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      trendsFilter = {
        display            = "ActionsLineGraph"
        showLegend         = false
        showValuesOnSeries = true
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "error_type_trend" {
  name        = "Errors by type"
  description = "Frontend exception trend broken down by $exception_types."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      breakdownFilter = {
        breakdown_type                   = "event"
        breakdown                        = "$exception_types"
        breakdown_limit                  = 10
        breakdown_hide_other_aggregation = false
      }
      trendsFilter = {
        display        = "ActionsLineGraph"
        showLegend     = true
        legendPosition = "bottom"
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "domain_trend" {
  name        = "Errors by domain"
  description = "Frontend exception trend broken down by the standard $host property."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      breakdownFilter = {
        breakdown_type                   = "event"
        breakdown                        = "$host"
        breakdown_limit                  = 10
        breakdown_hide_other_aggregation = false
      }
      trendsFilter = {
        display        = "ActionsLineGraph"
        showLegend     = true
        legendPosition = "bottom"
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "tenant_trend" {
  name        = "Errors by tenant"
  description = "Frontend exception trend broken down by ${var.tenant_property}."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      breakdownFilter = {
        breakdown_type                   = "event"
        breakdown                        = var.tenant_property
        breakdown_limit                  = 20
        breakdown_hide_other_aggregation = false
      }
      trendsFilter = {
        display        = "ActionsLineGraph"
        showLegend     = true
        legendPosition = "bottom"
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "frontend_error_rate_trend" {
  name        = "Frontend error rate trend"
  description = "Hourly percentage of intake pageview sessions that contain at least one frontend exception."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "unique_session"
          custom_name = "Sessions with errors"
        },
        {
          kind        = "EventsNode"
          event       = "$pageview"
          math        = "unique_session"
          custom_name = "Intake sessions"
        }
      ]
      trendsFilter = {
        display = "ActionsLineGraph"
        formulaNodes = [
          {
            formula     = "A / B * 100"
            custom_name = "Frontend error rate"
          }
        ]
        aggregationAxisFormat = "percentage"
        decimalPlaces         = 2
        showLegend            = false
        showValuesOnSeries    = true
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "top_error_issues" {
  name        = "Top error issues"
  description = "Hourly frontend exception trend for the top PostHog error issues."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      breakdownFilter = {
        breakdown_type                   = "event"
        breakdown                        = "$exception_issue_id"
        breakdown_limit                  = 10
        breakdown_hide_other_aggregation = false
      }
      trendsFilter = {
        display        = "ActionsLineGraph"
        showLegend     = true
        legendPosition = "bottom"
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "unhandled_error_trend" {
  name        = "Unhandled error trend"
  description = "Hourly unhandled frontend exception volume for the intake page."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties = [
        local.intake_path_filter,
        {
          key      = "$exception_handled"
          operator = "exact"
          type     = "event"
          value    = false
        }
      ]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Unhandled errors"
        }
      ]
      trendsFilter = {
        display            = "ActionsLineGraph"
        showLegend         = false
        showValuesOnSeries = true
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "browser_trend" {
  name        = "Errors by browser"
  description = "Hourly frontend exception trend broken down by browser."

  query_json = jsonencode({
    kind        = "InsightVizNode"
    showFilters = true
    source = {
      kind               = "TrendsQuery"
      dateRange          = local.default_date_range
      filterTestAccounts = false
      interval           = "hour"
      properties         = [local.intake_path_filter]
      series = [
        {
          kind        = "EventsNode"
          event       = "$exception"
          math        = "total"
          custom_name = "Frontend errors"
        }
      ]
      breakdownFilter = {
        breakdown_type                   = "event"
        breakdown                        = "$browser"
        breakdown_limit                  = 10
        breakdown_hide_other_aggregation = false
      }
      trendsFilter = {
        display        = "ActionsLineGraph"
        showLegend     = true
        legendPosition = "bottom"
      }
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

resource "posthog_insight" "error_list" {
  name        = "Frontend error list"
  description = "Latest frontend exceptions for the exact intake path, including tenant, environment, source, replay, form variant, error and session context."

  query_json = jsonencode({
    kind               = "DataTableNode"
    full               = true
    showDateRange      = true
    showPropertyFilter = true
    showReload         = true
    showExport         = true
    source = {
      kind               = "EventsQuery"
      event              = "$exception"
      after              = "-1d"
      filterTestAccounts = false
      fixedProperties    = [local.intake_path_filter]
      properties         = []
      select = [
        "timestamp AS time",
        "properties.${var.tenant_property} AS tenant_id",
        "properties.$host AS domain",
        "properties.$exception_level AS exception_level",
        "properties.$exception_types[1] AS error_type",
        "properties.$exception_values[1] AS error_message",
        "properties.$exception_sources[1] AS error_source",
        "properties.$current_url AS url",
        "properties.$exception_issue_id AS issue_id",
        "properties.$session_id AS session_id",
        "properties.$browser AS browser",
        "properties.$browser_version AS browser_version",
        "properties.$os AS os",
        "properties.$os_version AS os_version",
        "properties.$device_type AS device_type",
        "properties.$raw_user_agent AS raw_user_agent",
        "properties.$exception_handled AS handled",
        "properties.$has_recording AS has_recording",
        "properties['$feature/intake_form__nad_sermorelin'] AS intake_form_variant",
        "distinct_id",
      ]
      orderBy = ["timestamp DESC"]
      limit   = 200
    }
  })

  dashboard_ids = [posthog_dashboard.intake_error.id]
  depends_on    = [posthog_dashboard.intake_error]
}

# This resource authoritatively manages every tile on the dashboard.
resource "posthog_dashboard_layout" "intake_error" {
  dashboard_id = posthog_dashboard.intake_error.id

  tiles = [
    {
      insight_id       = posthog_insight.frontend_error_count.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 0, w = 6, h = 3 }
      })
    },
    {
      insight_id       = posthog_insight.frontend_error_rate.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 6, y = 0, w = 6, h = 3 }
      })
    },
    {
      insight_id       = posthog_insight.error_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 3, w = 12, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.frontend_error_rate_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 8, w = 12, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.top_error_issues.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 13, w = 6, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.unhandled_error_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 6, y = 13, w = 6, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.error_type_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 18, w = 6, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.domain_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 6, y = 18, w = 6, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.tenant_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 23, w = 12, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.browser_trend.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 28, w = 12, h = 5 }
      })
    },
    {
      insight_id       = posthog_insight.error_list.id
      show_description = true
      layouts_json = jsonencode({
        sm = { x = 0, y = 33, w = 12, h = 8 }
      })
    }
  ]

  depends_on = [
    posthog_insight.frontend_error_count,
    posthog_insight.frontend_error_rate,
    posthog_insight.error_trend,
    posthog_insight.error_type_trend,
    posthog_insight.domain_trend,
    posthog_insight.tenant_trend,
    posthog_insight.error_list,
    posthog_insight.frontend_error_rate_trend,
    posthog_insight.top_error_issues,
    posthog_insight.unhandled_error_trend,
    posthog_insight.browser_trend,
  ]
}
