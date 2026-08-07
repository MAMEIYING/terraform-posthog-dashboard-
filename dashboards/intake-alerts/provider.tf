provider "posthog" {
  host       = var.posthog_host
  project_id = var.posthog_project_id
  api_key    = var.posthog_api_key
}

provider "restapi" {
  uri                  = trimsuffix(var.posthog_host, "/")
  bearer_token         = var.posthog_api_key
  id_attribute         = "id"
  write_returns_object = true
}
