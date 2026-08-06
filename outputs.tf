output "dashboard_id" {
  description = "ID of the created PostHog dashboard."
  value       = posthog_dashboard.intake_error.id
}

output "dashboard_url" {
  description = "URL of the created PostHog dashboard."
  value = format(
    "%s/project/%s/dashboard/%s",
    trimsuffix(var.posthog_host, "/"),
    var.posthog_project_id,
    posthog_dashboard.intake_error.id,
  )
}

output "insight_ids" {
  description = "IDs of the intake error dashboard insights."
  value = {
    frontend_error_count = posthog_insight.frontend_error_count.id
    frontend_error_rate  = posthog_insight.frontend_error_rate.id
    error_trend          = posthog_insight.error_trend.id
    error_type_trend     = posthog_insight.error_type_trend.id
    domain_trend         = posthog_insight.domain_trend.id
    tenant_trend         = posthog_insight.tenant_trend.id
    error_list           = posthog_insight.error_list.id
    error_rate_trend     = posthog_insight.frontend_error_rate_trend.id
    top_error_issues     = posthog_insight.top_error_issues.id
    unhandled_trend      = posthog_insight.unhandled_error_trend.id
    browser_trend        = posthog_insight.browser_trend.id
  }
}
