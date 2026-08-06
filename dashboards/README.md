# Dashboard roots

> English | [中文](./README.zh.md)

Each subdirectory is an independent Terraform root module with its own state. Run the corresponding dashboard commands through the `Makefile` in the project root.

## Migrate existing local state

When upgrading from the legacy root-directory layout, run `make migrate-<dashboard-name>` first. The command moves the root `terraform.tfstate` and optional backup only when the destination state does not exist. It fails if both the source and destination exist or if the state is locked, preventing data from being overwritten.

After migration, run `make plan-<dashboard-name>` and confirm that the plan for existing resources reports `No changes`. Team environments should use an encrypted remote backend so state does not depend on one workstation.

## Add a dashboard

1. Create an independent Terraform configuration under `dashboards/<dashboard-name>/`.
2. Declare the shared variables `posthog_host`, `posthog_project_id`, and `posthog_api_key`.
3. Store non-sensitive business settings in the directory's `dashboard.tfvars.json`.
4. Register the name in `DASHBOARDS` in the root `Makefile`.
5. Run `make init-<dashboard-name>`, `make plan-<dashboard-name>`, and `make apply-<dashboard-name>`.

Do not share one `terraform.tfstate` between dashboard directories, and do not use `-target` as a substitute for state isolation.
