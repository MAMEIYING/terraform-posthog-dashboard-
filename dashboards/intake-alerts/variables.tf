variable "posthog_host" {
  description = "PostHog API base URL. Use https://us.posthog.com or https://eu.posthog.com for PostHog Cloud."
  type        = string
  default     = "https://us.posthog.com"

  validation {
    condition     = can(regex("^https://", var.posthog_host))
    error_message = "posthog_host must be an HTTPS URL."
  }
}

variable "posthog_project_id" {
  description = "PostHog project/environment ID."
  type        = string

  validation {
    condition     = length(trimspace(var.posthog_project_id)) > 0
    error_message = "posthog_project_id must not be empty."
  }
}

variable "posthog_api_key" {
  description = "PostHog Personal API Key. Store it only in an ignored .tfvars file."
  type        = string
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(trimspace(var.posthog_api_key)) > 0
    error_message = "posthog_api_key must not be empty."
  }
}

variable "intake_path" {
  description = "Exact pathname monitored by the intake alerts."
  type        = string
  default     = "/intake"

  validation {
    condition     = startswith(var.intake_path, "/")
    error_message = "intake_path must start with /."
  }
}

variable "slack_workspace_id" {
  description = "PostHog integration ID for the Slack workspace used by alert destinations."
  type        = number
}

variable "slack_channels" {
  description = "Slack destination channel names keyed by channel ID."
  type        = map(string)

  validation {
    condition     = length(var.slack_channels) > 0
    error_message = "slack_channels must contain at least one destination."
  }
}
