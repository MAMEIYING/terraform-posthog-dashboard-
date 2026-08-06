output "dashboard_id" {
  description = "ID of the managed PostHog dashboard."
  value       = posthog_dashboard.intake_performance.id
}

output "dashboard_url" {
  description = "URL of the managed PostHog dashboard."
  value = format(
    "%s/project/%s/dashboard/%s",
    trimsuffix(var.posthog_host, "/"),
    var.posthog_project_id,
    posthog_dashboard.intake_performance.id,
  )
}

output "insight_ids" {
  description = "IDs of the intake performance dashboard insights."
  value = {
    for key, insight in posthog_insight.intake_performance : key => insight.id
  }
}
