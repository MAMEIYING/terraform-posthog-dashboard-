locals {
  overview_percentile_metric_definitions = {
    inp = {
      property       = "$web_vitals_INP_value"
      divisor        = "1.0"
      decimal_places = 0
      suffix         = "ms"
      x              = 0
      value_selector = "nullIf(argMaxIf(value, bucket, value != 0), 0)"
      metric_order   = 1
      is_cls         = 0
      good_threshold = 200
      poor_threshold = 500
    }
    lcp = {
      property       = "$web_vitals_LCP_value"
      divisor        = "1000.0"
      decimal_places = 2
      suffix         = "s"
      x              = 3
      value_selector = "nullIf(argMaxIf(value, bucket, value != 0), 0)"
      metric_order   = 2
      is_cls         = 0
      good_threshold = 2.5
      poor_threshold = 4
    }
    fcp = {
      property       = "$web_vitals_FCP_value"
      divisor        = "1.0"
      decimal_places = 0
      suffix         = "ms"
      x              = 6
      value_selector = "nullIf(argMaxIf(value, bucket, value != 0), 0)"
      metric_order   = 3
      is_cls         = 0
      good_threshold = 1800
      poor_threshold = 3000
    }
    cls = {
      property       = "$web_vitals_CLS_value"
      divisor        = "1.0"
      decimal_places = 2
      suffix         = ""
      x              = 9
      value_selector = "if(countIf(value != 0) = 0, NULL, argMax(value, bucket))"
      metric_order   = 4
      is_cls         = 1
      good_threshold = 0.1
      poor_threshold = 0.25
    }
  }

  overview_percentile_card_insights = merge([
    for metric_key, metric in local.overview_percentile_metric_definitions : {
      for percentile in [90, 99] : "intake_${metric_key}_p${percentile}_web_analytics" => {
        name        = "Intake ${upper(metric_key)} P${percentile} (Web Analytics)"
        description = "P${percentile} card aligned with the PostHog Web Analytics Web Vitals query and cleaned-path filter."
        layout = {
          x = metric.x
          y = percentile == 90 ? 6 : 9
          w = 3
          h = 3
        }
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
              WITH filtered AS (
                  SELECT
                      timestamp,
                      toFloat(properties.${metric.property}) / ${metric.divisor} AS metric
                  FROM events
                  WHERE event = '$web_vitals'
                    AND properties.${metric.property} IS NOT NULL
                    AND timestamp <= now()
                    AND {filters}
              ),
              bucketed AS (
                  SELECT
                      toStartOfHour(timestamp) AS bucket,
                      quantile(${percentile / 100})(metric) AS value
                  FROM filtered
                  GROUP BY bucket
              )
              SELECT round(${metric.value_selector}, ${metric.decimal_places}) AS value
              FROM bucketed
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
                    style         = "none"
                    prefix        = ""
                    suffix        = metric.suffix
                    decimalPlaces = metric.decimal_places
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
                    style         = "none"
                    prefix        = ""
                    suffix        = metric.suffix
                    decimalPlaces = metric.decimal_places
                  }
                }
              }
            ]
          }
        }
      }
    }
  ]...)

  overview_percentile_card_order = [
    "intake_inp_p90_web_analytics",
    "intake_lcp_p90_web_analytics",
    "intake_fcp_p90_web_analytics",
    "intake_cls_p90_web_analytics",
    "intake_inp_p99_web_analytics",
    "intake_lcp_p99_web_analytics",
    "intake_fcp_p99_web_analytics",
    "intake_cls_p99_web_analytics",
  ]

  conditional_equals_bytecode = [
    "_H",
    32,
    "input",
    1,
    1,
    32,
    "value",
    1,
    1,
    11,
    38,
  ]

  percentile_status_colors = {
    Good                = "#C1FBA4"
    "Needs improvement" = "#FDFFB6"
    Poor                = "#FFADAD"
  }

  percentile_status_columns = [
    "p75_status",
    "p90_status",
    "p99_status",
  ]

  percentile_status_conditional_formatting = flatten([
    for column in local.percentile_status_columns : [
      for status, color in local.percentile_status_colors : {
        id         = "${column}_${replace(lower(status), " ", "_")}"
        templateId = "equals"
        columnName = column
        bytecode   = local.conditional_equals_bytecode
        input      = status
        color      = color
        colorMode  = "light"
      }
    ]
  ])

  percentile_status_filtered_selects = [
    for metric_key, metric in local.overview_percentile_metric_definitions : trimspace(<<-HOGQL
      SELECT
          timestamp,
          ${metric.metric_order} AS metric_order,
          '${upper(metric_key)}' AS metric,
          ${metric.is_cls} AS is_cls,
          ${metric.good_threshold} AS good_threshold,
          ${metric.poor_threshold} AS poor_threshold,
          toFloat(properties.${metric.property}) / ${metric.divisor} AS value
      FROM events
      WHERE event = '$web_vitals'
        AND properties.${metric.property} IS NOT NULL
        AND timestamp <= now()
        AND {filters}
    HOGQL
    )
  ]

  overview_percentile_status_query = <<-HOGQL
    WITH filtered AS (
        ${join("\n        UNION ALL\n        ", local.percentile_status_filtered_selects)}
    ),
    bucketed AS (
        SELECT
            metric_order,
            metric,
            is_cls,
            good_threshold,
            poor_threshold,
            toStartOfHour(timestamp) AS bucket,
            count() AS samples,
            quantile(0.75)(value) AS p75,
            quantile(0.90)(value) AS p90,
            quantile(0.99)(value) AS p99
        FROM filtered
        GROUP BY metric_order, metric, is_cls, good_threshold, poor_threshold, bucket
    ),
    latest AS (
        SELECT
            metric_order,
            metric,
            good_threshold,
            poor_threshold,
            if(max(is_cls) = 1,
               if(countIf(p75 != 0) = 0, NULL, argMax(samples, bucket)),
               if(countIf(p75 != 0) = 0, NULL, argMaxIf(samples, bucket, p75 != 0))) AS samples,
            if(max(is_cls) = 1,
               if(countIf(p75 != 0) = 0, NULL, argMax(p75, bucket)),
               nullIf(argMaxIf(p75, bucket, p75 != 0), 0)) AS p75,
            if(max(is_cls) = 1,
               if(countIf(p90 != 0) = 0, NULL, argMax(p90, bucket)),
               nullIf(argMaxIf(p90, bucket, p90 != 0), 0)) AS p90,
            if(max(is_cls) = 1,
               if(countIf(p99 != 0) = 0, NULL, argMax(p99, bucket)),
               nullIf(argMaxIf(p99, bucket, p99 != 0), 0)) AS p99
        FROM bucketed
        GROUP BY metric_order, metric, good_threshold, poor_threshold
    )
    SELECT
        metric,
        samples,
        if(p75 IS NULL, '—', multiIf(
            metric = 'LCP', concat(toString(round(p75, 2)), ' s'),
            metric = 'CLS', toString(round(p75, 2)),
            concat(toString(round(p75, 0)), ' ms')
        )) AS p75_value,
        multiIf(p75 IS NULL, 'No data', p75 <= good_threshold, 'Good',
                p75 <= poor_threshold, 'Needs improvement', 'Poor') AS p75_status,
        if(p90 IS NULL, '—', multiIf(
            metric = 'LCP', concat(toString(round(p90, 2)), ' s'),
            metric = 'CLS', toString(round(p90, 2)),
            concat(toString(round(p90, 0)), ' ms')
        )) AS p90_value,
        multiIf(p90 IS NULL, 'No data', p90 <= good_threshold, 'Good',
                p90 <= poor_threshold, 'Needs improvement', 'Poor') AS p90_status,
        if(p99 IS NULL, '—', multiIf(
            metric = 'LCP', concat(toString(round(p99, 2)), ' s'),
            metric = 'CLS', toString(round(p99, 2)),
            concat(toString(round(p99, 0)), ' ms')
        )) AS p99_value,
        multiIf(p99 IS NULL, 'No data', p99 <= good_threshold, 'Good',
                p99 <= poor_threshold, 'Needs improvement', 'Poor') AS p99_status
    FROM latest
    ORDER BY metric_order
  HOGQL
}

resource "posthog_insight" "intake_performance_overview_percentiles" {
  for_each = local.overview_percentile_card_insights

  name          = each.value.name
  description   = each.value.description
  query_json    = jsonencode(each.value.query)
  dashboard_ids = []

  # PostHog Provider 1.0.x cannot detach an existing Insight tile by updating
  # dashboard_ids to an empty set. The dashboard layout remains authoritative
  # for tile membership, while these Insights stay managed for rollback.
  lifecycle {
    ignore_changes = [dashboard_ids]
  }

  depends_on = [posthog_dashboard.intake_performance]
}

resource "posthog_insight" "intake_performance_overview_percentile_status" {
  name          = "Intake Web Vitals percentile status"
  description   = null
  dashboard_ids = []
  query_json = jsonencode({
    kind = "DataVisualizationNode"
    source = {
      kind = "HogQLQuery"
      filters = {
        dateRange          = local.default_date_range
        filterTestAccounts = false
        properties         = [local.cleaned_path_filter]
      }
      query = trimspace(local.overview_percentile_status_query)
    }
    display = "ActionsTable"
    tableSettings = {
      columns = [
        { column = "metric", settings = { display = { label = "Metric" } } },
        { column = "samples", settings = { display = { label = "Samples" } } },
        { column = "p75_value", settings = { display = { label = "P75" } } },
        { column = "p75_status", settings = { display = { label = "P75 status" } } },
        { column = "p90_value", settings = { display = { label = "P90" } } },
        { column = "p90_status", settings = { display = { label = "P90 status" } } },
        { column = "p99_value", settings = { display = { label = "P99" } } },
        { column = "p99_status", settings = { display = { label = "P99 status" } } },
      ]
      conditionalFormatting = local.percentile_status_conditional_formatting
    }
  })

  # Keep the existing Insight managed for rollback, but remove its Overview
  # tile because its fixed hourly HogQL cannot follow dashboard intervals.
  lifecycle {
    ignore_changes = [dashboard_ids]
  }

  depends_on = [posthog_dashboard.intake_performance]
}

resource "terraform_data" "intake_performance_overview_percentile_tile_cleanup" {
  triggers_replace = sha256(jsonencode({
    revision     = 2
    dashboard_id = posthog_dashboard.intake_performance.id
    insight_ids = concat(
      [
        for key in local.overview_percentile_card_order :
        posthog_insight.intake_performance_overview_percentiles[key].id
      ],
      [posthog_insight.intake_performance_overview_percentile_status.id],
    )
  }))

  provisioner "local-exec" {
    command = format(
      "sh %s/../../scripts/cleanup-posthog-dashboard-tiles.sh %s %s %s %s",
      path.module,
      trimsuffix(var.posthog_host, "/"),
      var.posthog_project_id,
      posthog_dashboard.intake_performance.id,
      join(" ", concat(
        [
          for key in local.overview_percentile_card_order :
          posthog_insight.intake_performance_overview_percentiles[key].id
        ],
        [posthog_insight.intake_performance_overview_percentile_status.id],
      )),
    )
    environment = {
      POSTHOG_API_KEY = var.posthog_api_key
    }
  }

  depends_on = [posthog_dashboard_layout.intake_performance]
}
