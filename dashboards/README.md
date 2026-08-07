# Dashboard roots

> English | [中文](./README.zh.md)

Each subdirectory is an independent Terraform root module. Each root then uses an independent `project-<posthog_project_id>` workspace for every PostHog project. Run dashboard commands through the project-root `Makefile`.

## Project workspaces

The Makefile reads `posthog_project_id` from the Git-ignored root `terraform.tfvars` and sets a command-scoped `TF_WORKSPACE` for every stateful operation. As a result, `plan`, `apply`, `destroy`, `output`, `state-list`, and import commands do not depend on the interactively selected workspace.

Create a workspace once for each dashboard when first managing a project:

```bash
make init-<dashboard-name>
make workspace-new-<dashboard-name>
make workspace-show-<dashboard-name>
make plan-<dashboard-name>
```

Stateful commands fail when the workspace is missing instead of falling back to `default`. Never reuse one State across different PostHog projects.

## Migrate existing local State

When upgrading root-level or dashboard `default` State, first confirm that `terraform.tfvars` identifies the PostHog project actually managed by that State. Then run `make migrate-<dashboard-name>`. The command moves the State and optional backup into `terraform.tfstate.d/project-<ID>/`.

Migration fails without overwriting files when root and dashboard `default` State both exist, source and target State both exist, a target backup already exists, or any State is locked. After migrating, run `make workspace-show-<dashboard-name>` and `make plan-<dashboard-name>`; existing resources must report `No changes`.

## Add a dashboard

1. Create an independent Terraform configuration under `dashboards/<dashboard-name>/`.
2. Declare the shared variables `posthog_host`, `posthog_project_id`, and `posthog_api_key`.
3. Store non-sensitive business settings in the directory's `dashboard.tfvars.json`.
4. Register the name in `DASHBOARDS` in the root `Makefile`.
5. Run `make init-<dashboard-name>`, `make workspace-new-<dashboard-name>`, `make plan-<dashboard-name>`, and `make apply-<dashboard-name>` in order.

Do not use `-target` as a substitute for root-module and project-workspace State isolation.
