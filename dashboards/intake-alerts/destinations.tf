locals {
  slack_channel_ids = {
    for channel_id, channel_name in var.slack_channels : channel_name => channel_id
  }

  slack_destination_hog = trimspace(<<-HOG
    let res := fetch('https://slack.com/api/chat.postMessage', {
      'body': {
        'channel': inputs.channel,
        'icon_emoji': inputs.icon_emoji,
        'username': inputs.username,
        'blocks': inputs.blocks,
        'text': inputs.text
      },
      'method': 'POST',
      'headers': {
        'Authorization': f'Bearer {inputs.slack_workspace.access_token}',
        'Content-Type': 'application/json'
      }
    });

    if (res.status != 200 or res.body.ok == false) {
      throw Error(f'Failed to post message to Slack: {res.status}: {res.body}');
    }
  HOG
  )

  slack_alert_blocks = [
    {
      text = {
        text = "Alert '{event.properties.alert_name}' firing for insight '{event.properties.insight_name}'"
        type = "plain_text"
      }
      type = "header"
    },
    {
      text = {
        text = "{event.properties.breaches}"
        type = "plain_text"
      }
      type = "section"
    },
    {
      type = "context"
      elements = [
        {
          text = "Project: <{project.url}|{project.name}>"
          type = "mrkdwn"
        },
      ]
    },
    {
      type = "divider"
    },
    {
      type     = "actions"
      block_id = "insight_alert_snooze:{event.properties.alert_id}"
      elements = [
        {
          url  = "{event.properties.investigation_notebook_url ? event.properties.investigation_notebook_url : concat(project.url, '/insights/', event.properties.insight_id, '/alerts?alert_id=', event.properties.alert_id, '&utm_source=alert&utm_campaign=alert_check_firing&utm_medium=slack')}"
          type = "button"
          text = {
            text = "{event.properties.investigation_notebook_url ? 'View Investigation' : 'View Alert'}"
            type = "plain_text"
          }
        },
        {
          url  = "{project.url}/insights/{event.properties.insight_id}?utm_source=alert&utm_campaign=alert_check_firing&utm_medium=slack"
          type = "button"
          text = {
            text = "View Insight"
            type = "plain_text"
          }
        },
        {
          type      = "static_select"
          action_id = "insight_alert_snooze"
          placeholder = {
            text = "Snooze…"
            type = "plain_text"
          }
          options = [
            {
              text = {
                text = "For 1 hour"
                type = "plain_text"
              }
              value = "{event.properties.alert_id}|1h"
            },
            {
              text = {
                text = "For 6 hours"
                type = "plain_text"
              }
              value = "{event.properties.alert_id}|6h"
            },
            {
              text = {
                text = "For 1 day"
                type = "plain_text"
              }
              value = "{event.properties.alert_id}|1d"
            },
            {
              text = {
                text = "For 1 week"
                type = "plain_text"
              }
              value = "{event.properties.alert_id}|1w"
            },
            {
              text = {
                text = "Pick a date & time…"
                type = "plain_text"
              }
              value = "{event.properties.alert_id}|custom"
            },
          ]
        },
      ]
    },
  ]

  slack_destinations = {
    frontend_error_test_alert = {
      name       = "[Warning] Frontend error count >= 3 / 15m: Slack #test-alert"
      alert_key  = "frontend_error"
      channel_id = local.slack_channel_ids["test-alert"]
    }
    p0_lcp_test_alert = {
      name       = "[P0] Intake LCP critical (10m, n>=20): Slack #test-alert"
      alert_key  = "p0_lcp"
      channel_id = local.slack_channel_ids["test-alert"]
    }
    warning_lcp_test_alert = {
      name       = "[Warning] Intake LCP P95 > 8s (10m, n>=20): Slack #test-alert"
      alert_key  = "warning_lcp"
      channel_id = local.slack_channel_ids["test-alert"]
    }
    frontend_error_staging = {
      name       = "[Warning]Intake Frontend error count >= 3 / 15m: Slack #fd-launchpad-intake-monitor-staging"
      alert_key  = "frontend_error"
      channel_id = local.slack_channel_ids["fd-launchpad-intake-monitor-staging"]
    }
    p0_lcp_staging = {
      name       = "[P0] Intake LCP critical (10m, n>=20): Slack #fd-launchpad-intake-monitor-staging"
      alert_key  = "p0_lcp"
      channel_id = local.slack_channel_ids["fd-launchpad-intake-monitor-staging"]
    }
    warning_lcp_staging = {
      name       = "[Warning] Intake LCP P95 > 8s (10m, n>=20): Slack #fd-launchpad-intake-monitor-staging"
      alert_key  = "warning_lcp"
      channel_id = local.slack_channel_ids["fd-launchpad-intake-monitor-staging"]
    }
  }
}

resource "posthog_hog_function" "slack_alert" {
  for_each = local.slack_destinations

  name        = each.value.name
  description = "Sends a message to a Slack channel"
  type        = "internal_destination"
  template_id = "template-slack"
  enabled     = true
  hog         = local.slack_destination_hog
  icon_url    = "/static/services/slack.png"

  filters_json = jsonencode({
    source = "events"
    events = [
      {
        id   = "$insight_alert_firing"
        type = "events"
      }
    ]
    properties = [
      {
        key      = "alert_id"
        type     = "event"
        value    = restapi_object.intake_alert[each.value.alert_key].id
        operator = "exact"
      }
    ]
  })

  inputs_json = jsonencode({
    slack_workspace = {
      value = var.slack_workspace_id
    }
    channel = {
      value = each.value.channel_id
    }
    blocks = {
      value = local.slack_alert_blocks
    }
    text = {
      value = "Alert triggered: {event.properties.insight_name}"
    }
    username   = null
    icon_emoji = null
  })
}
