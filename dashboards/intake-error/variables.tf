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
  description = "Name of the PostHog dashboard."
  type        = string
  default     = "Intake Frontend Error"
}

variable "dashboard_tags" {
  description = "Tags assigned to the PostHog dashboard."
  type        = set(string)
  default     = ["error-tracking", "intake"]
}

variable "intake_path" {
  description = "Exact pathname included in the intake error dashboard."
  type        = string
  default     = "/intake"

  validation {
    condition     = startswith(var.intake_path, "/")
    error_message = "intake_path must start with /."
  }
}

variable "tenant_property" {
  description = "Event property containing the tenant ID."
  type        = string
  default     = "tenant_id"

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.tenant_property))
    error_message = "tenant_property must be a valid HogQL property identifier."
  }
}
