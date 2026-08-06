output "dashboard_id" {
  description = "ID of the managed PostHog overview dashboard."
  value       = posthog_dashboard.intake_performance.id
}

output "dashboard_url" {
  description = "URL of the managed PostHog overview dashboard."
  value = format(
    "%s/project/%s/dashboard/%s",
    trimsuffix(var.posthog_host, "/"),
    var.posthog_project_id,
    posthog_dashboard.intake_performance.id,
  )
}

output "diagnostics_dashboard_id" {
  description = "ID of the managed PostHog diagnostics dashboard."
  value       = posthog_dashboard.intake_performance_diagnostics.id
}

output "diagnostics_dashboard_url" {
  description = "URL of the managed PostHog diagnostics dashboard."
  value = format(
    "%s/project/%s/dashboard/%s",
    trimsuffix(var.posthog_host, "/"),
    var.posthog_project_id,
    posthog_dashboard.intake_performance_diagnostics.id,
  )
}

output "insight_ids" {
  description = "IDs of all intake performance insights."
  value = merge(
    {
      for key, insight in posthog_insight.intake_performance : key => insight.id
    },
    {
      for key, insight in posthog_insight.intake_performance_overview_quality : key => insight.id
    },
    {
      for key, insight in posthog_insight.intake_performance_overview_percentiles : key => insight.id
    },
    {
      intake_web_vitals_percentile_status = posthog_insight.intake_performance_overview_percentile_status.id
    },
    {
      for key, insight in posthog_insight.intake_performance_diagnostics : key => insight.id
    },
  )
}
