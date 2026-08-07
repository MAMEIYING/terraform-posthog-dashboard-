locals {
  intake_alert_insights = {
    p0_lcp = {
      name = "P0 - Intake LCP critical (10m, n>=20)"
      columns = [
        "samples_10m",
        "samples_5m",
        "lcp_p95_5m_ms",
        "over_10s_pct",
        "p0_firing",
      ]
      query = trimspace(<<-HOGQL
        WITH per_pageview AS (
            SELECT
                properties.$pageview_id AS pageview_id,
                argMax(toFloat(properties.$web_vitals_LCP_value), timestamp) AS lcp_ms,
                max(timestamp) AS sample_time
            FROM events
            WHERE event = '$web_vitals'
              AND properties.$pathname = '${var.intake_path}'
              AND properties.$pageview_id IS NOT NULL
              AND properties.$web_vitals_LCP_value IS NOT NULL
              AND timestamp >= now() - INTERVAL 10 MINUTE
            GROUP BY pageview_id
        )
        SELECT
            count() AS samples_10m,
            countIf(sample_time >= now() - INTERVAL 5 MINUTE) AS samples_5m,
            round(if(samples_5m > 0, quantileIf(0.95)(lcp_ms, sample_time >= now() - INTERVAL 5 MINUTE), 0), 0) AS lcp_p95_5m_ms,
            round(if(samples_10m > 0, 100.0 * countIf(lcp_ms > 10000) / samples_10m, 0), 2) AS over_10s_pct,
            if(samples_10m >= 20 AND (lcp_p95_5m_ms > 15000 OR over_10s_pct > 20), 1, 0) AS p0_firing
        FROM per_pageview
      HOGQL
      )
    }

    warning_lcp = {
      name = "Warning - Intake LCP P95 > 8s (10m, n>=20)"
      columns = [
        "samples_10m",
        "lcp_p95_ms",
        "warning_firing",
      ]
      query = trimspace(<<-HOGQL
        WITH per_pageview AS (
            SELECT
                properties.$pageview_id AS pageview_id,
                argMax(toFloat(properties.$web_vitals_LCP_value), timestamp) AS lcp_ms
            FROM events
            WHERE event = '$web_vitals'
              AND properties.$pathname = '${var.intake_path}'
              AND properties.$pageview_id IS NOT NULL
              AND properties.$web_vitals_LCP_value IS NOT NULL
              AND timestamp >= now() - INTERVAL 10 MINUTE
            GROUP BY pageview_id
        )
        SELECT
            count() AS samples_10m,
            round(if(count() > 0, quantile(0.95)(lcp_ms), 0), 0) AS lcp_p95_ms,
            if(samples_10m >= 20 AND lcp_p95_ms > 8000, 1, 0) AS warning_firing
        FROM per_pageview
      HOGQL
      )
    }

    frontend_error = {
      name = "Warning - Intake Frontend error count >= 3 / 15m"
      columns = [
        "errors_15m",
        "warning_firing",
      ]
      query = trimspace(<<-HOGQL
        SELECT
            count() AS errors_15m,
            if(errors_15m >= 3, 1, 0) AS warning_firing
        FROM events
        WHERE event = '$exception'
          AND properties.$pathname = '${var.intake_path}'
          AND timestamp >= now() - INTERVAL 15 MINUTE
      HOGQL
      )
    }
  }
}

resource "posthog_insight" "intake_alert" {
  for_each = local.intake_alert_insights

  name = each.value.name

  query_json = jsonencode({
    kind = "DataVisualizationNode"
    source = {
      kind  = "HogQLQuery"
      query = each.value.query
    }
    display = "ActionsTable"
    chartSettings = {
      yAxis = [
        for column in each.value.columns : {
          column = column
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
        for column in each.value.columns : {
          column = column
          settings = {
            formatting = {
              prefix = ""
              suffix = ""
            }
          }
        }
      ]
    }
  })
}
