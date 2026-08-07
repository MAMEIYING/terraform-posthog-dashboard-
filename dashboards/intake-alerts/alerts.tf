locals {
  intake_alerts = {
    p0_lcp = {
      name         = "[P0] Intake LCP critical (10m, n>=20)"
      column       = "p0_firing"
      label_column = "samples_10m"
    }
    warning_lcp = {
      name         = "[Warning] Intake LCP P95 > 8s (10m, n>=20)"
      column       = "warning_firing"
      label_column = "samples_10m"
    }
    frontend_error = {
      name         = "[Warning]Intake Frontend error count >= 3 / 15m"
      column       = "warning_firing"
      label_column = "errors_15m"
    }
  }

  alerts_api_path = "/api/environments/${var.posthog_project_id}/alerts"
  alert_read_patch = jsonencode([
    { op = "move", from = "/insight/id", path = "/managed_insight" },
    { op = "remove", path = "/insight" },
    { op = "move", from = "/managed_insight", path = "/insight" },
    { op = "move", from = "/threshold/configuration", path = "/managed_threshold_configuration" },
    { op = "remove", path = "/threshold" },
    { op = "add", path = "/threshold", value = {} },
    { op = "move", from = "/managed_threshold_configuration", path = "/threshold/configuration" },
    { op = "remove", path = "/id" },
    { op = "remove", path = "/created_at" },
    { op = "remove", path = "/created_by" },
    { op = "remove", path = "/checks" },
    { op = "remove", path = "/detector_config" },
    { op = "remove", path = "/last_checked_at" },
    { op = "remove", path = "/last_notified_at" },
    { op = "remove", path = "/last_value" },
    { op = "remove", path = "/next_check_at" },
    { op = "remove", path = "/schedule_restriction" },
    { op = "remove", path = "/snoozed_until" },
    { op = "remove", path = "/state" },
  ])
}

resource "restapi_object" "intake_alert" {
  for_each = local.intake_alerts

  path          = local.alerts_api_path
  id_attribute  = "id"
  read_path     = "${local.alerts_api_path}/"
  update_path   = "${local.alerts_api_path}/{id}/"
  update_method = "PATCH"
  destroy_path  = "${local.alerts_api_path}/{id}/"

  read_search = {
    search_key   = "id"
    search_value = "{id}"
    results_key  = "results"
    search_patch = local.alert_read_patch
  }

  data = jsonencode({
    name    = each.value.name
    insight = posthog_insight.intake_alert[each.key].id
    condition = {
      type = "absolute_value"
    }
    config = {
      type         = "HogQLAlertConfig"
      column       = each.value.column
      evaluation   = "last_row"
      label_column = each.value.label_column
    }
    threshold = {
      configuration = {
        type = "absolute"
        bounds = {
          upper = 0
        }
      }
    }
    calculation_interval              = "hourly"
    enabled                           = true
    skip_weekend                      = false
    subscribed_users                  = []
    investigation_agent_enabled       = false
    investigation_gates_notifications = false
    investigation_inconclusive_action = "notify"
  })
}
