output "insight_ids" {
  description = "IDs of the managed intake alert insights."
  value = {
    for key, insight in posthog_insight.intake_alert : key => insight.id
  }
}

output "alert_ids" {
  description = "UUIDs of the managed intake alerts."
  value = {
    for key, alert in restapi_object.intake_alert : key => alert.id
  }
}

output "alert_urls" {
  description = "PostHog URLs for the managed intake alerts."
  value = {
    for key, alert in restapi_object.intake_alert : key => format(
      "%s/project/%s/alerts/%s",
      trimsuffix(var.posthog_host, "/"),
      var.posthog_project_id,
      alert.id,
    )
  }
}

output "slack_destination_ids" {
  description = "UUIDs of the managed Slack alert destinations."
  value = {
    for key, destination in posthog_hog_function.slack_alert : key => destination.id
  }
}
