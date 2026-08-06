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

variable "dashboard_name" {
  description = "Name of the PostHog overview dashboard."
  type        = string
  default     = "Intake Performance Overview"
}

variable "diagnostics_dashboard_name" {
  description = "Name of the PostHog diagnostics dashboard."
  type        = string
  default     = "Intake Performance Diagnostics"
}

variable "dashboard_description" {
  description = "Description of the PostHog dashboard."
  type        = string
  default     = ""
}

variable "dashboard_pinned" {
  description = "Whether the PostHog dashboard is pinned."
  type        = bool
  default     = false
}

variable "dashboard_tags" {
  description = "Tags assigned to the PostHog dashboard."
  type        = set(string)
  default     = []
}

variable "date_from" {
  description = "Default rolling date range used by HogQL cards and PV/UV insights."
  type        = string
  default     = "-24h"

  validation {
    condition     = length(trimspace(var.date_from)) > 0
    error_message = "date_from must not be empty."
  }
}

variable "web_vitals_trend_date_from" {
  description = "Saved rolling date range of the Web Vitals Trends insights before dashboard-level overrides."
  type        = string
  default     = "-1h"

  validation {
    condition     = length(trimspace(var.web_vitals_trend_date_from)) > 0
    error_message = "web_vitals_trend_date_from must not be empty."
  }
}

variable "diagnostics_date_from" {
  description = "Default rolling date range used by diagnostics insights."
  type        = string
  default     = "-7d"

  validation {
    condition     = length(trimspace(var.diagnostics_date_from)) > 0
    error_message = "diagnostics_date_from must not be empty."
  }
}

variable "intake_path" {
  description = "Pathname included in the intake performance dashboard."
  type        = string
  default     = "/intake"

  validation {
    condition     = startswith(var.intake_path, "/")
    error_message = "intake_path must start with /."
  }
}
