# PostHog Dashboards with Terraform

> English | [中文](./README.zh.md)

This project uses the official PostHog Terraform Provider to manage multiple dashboards. Each dashboard is an independent Terraform root module with its own state and dedicated Make commands, so creating, updating, or deleting one dashboard does not affect the others.

## Project structure

```text
terraform-posthog-dashboard/
├── Makefile                         # Dashboard command entry point
├── terraform.tfvars                 # Shared connection settings and API key; never commit
├── terraform.tfvars.example         # Shared settings example
├── dashboards/
│   ├── README.md                     # Guide for adding dashboards
│   ├── README.zh.md                  # Chinese guide for adding dashboards
│   ├── intake-error/                 # Independent Intake Error root module and state
│   │   └── ...
│   └── intake-performance/           # Independent Intake Performance root module and state
│       ├── dashboard.tfvars.json     # Committable dashboard business configuration
│       ├── diagnostics.tf             # Diagnostics dashboard and investigation tables
│       ├── main.tf
│       ├── overview-percentiles.tf    # Managed rollback-only percentile cards and cleanup
│       ├── overview-quality.tf        # Overview quality and coverage cards
│       ├── outputs.tf
│       ├── provider.tf
│       ├── variables.tf
│       └── versions.tf
├── docs/
│   ├── intake-error.md               # Intake Error metrics and usage guide
│   ├── intake-error.zh.md            # Intake Error Chinese guide
│   ├── intake-performance.md         # Intake Performance metrics and usage guide
│   └── intake-performance.zh.md      # Intake Performance Chinese guide
└── scripts/
    ├── import-intake-performance.sh  # Idempotent import of existing PostHog resources
    └── cleanup-posthog-dashboard-tiles.sh
                                      # Removes obsolete Overview tiles during apply
```

## Supported dashboards

| Command name | PostHog dashboard | Documentation |
| --- | --- | --- |
| `intake-error` | `Intake Frontend Error` | [English](./docs/intake-error.md) / [Chinese](./docs/intake-error.zh.md) |
| `intake-performance` | `Intake Performance Overview` and `Intake Performance Diagnostics` | [English](./docs/intake-performance.md) / [Chinese](./docs/intake-performance.zh.md) |

## Intake Error dashboard

The Intake Error dashboard monitors frontend exceptions on `/intake`, including error volume, affected-session rate, time trends, issue attribution, and recent event details. Metrics query the latest day by default, match `$pathname` exactly to `/intake`, and use hourly buckets for trend charts.

For panel definitions, query semantics, validation results, filter guidance, and Terraform management boundaries, see the [English guide](./docs/intake-error.md) or [Chinese guide](./docs/intake-error.zh.md).

## Intake Performance dashboards

The two Intake Performance dashboards provide complementary views of `/intake` performance. Overview monitors the latest 24 hours through Web Vitals P75 trends, poor ratios, metric coverage, and PV/UV; Diagnostics investigates the latest seven days through P75/P90/P99 trends, tenant, organization, and domain breakdowns, and event-level Web Vitals reports.

For panel definitions, query semantics, data-quality findings, filter guidance, and Terraform management boundaries, see the [English guide](./docs/intake-performance.md) or [Chinese guide](./docs/intake-performance.zh.md).

## Prerequisites

- Terraform 1.10 or later
- A POSIX-compatible shell, `curl`, and `jq`; the Intake Performance cleanup step invokes them during `terraform apply`
- PostHog US Cloud project `92499`
- A PostHog Personal API Key with access to the target project
- Frontend events containing `$session_id`, `$pathname`, `$host`, `$device_type`, `$raw_user_agent`, and `tenant_id`; exception events must also contain `$exception_types` and `$exception_values`

### Install Terraform on macOS

If the terminal reports `/bin/sh: terraform: command not found`, install Terraform before running any dashboard commands. The recommended installation method is HashiCorp's official Homebrew tap:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

Confirm that `terraform version` reports Terraform 1.10.0 or later. If Homebrew is unavailable, download the appropriate macOS binary from the [official Terraform installation page](https://developer.hashicorp.com/terraform/install) and place it in a directory included in `PATH`.

The PostHog Provider does not require a separate manual installation. Initialize the dashboard first so Terraform downloads the required provider automatically:

```bash
make init-intake-error
```

After initialization succeeds, continue with `make plan-intake-error` and then `make apply-intake-error`.

## 1. Configure shared PostHog settings

The root `terraform.tfvars` stores only the PostHog connection settings shared by all dashboards. The file is excluded by `.gitignore`:

```hcl
posthog_project_id = "92499"
posthog_api_key    = "phx_your_personal_api_key"
posthog_host       = "https://us.posthog.com"
```

Store non-sensitive settings such as dashboard names, tags, and paths in the corresponding `dashboard.tfvars.json`, not in the shared `terraform.tfvars`.

`posthog_api_key` is declared as both `sensitive` and `ephemeral`. Terraform hides the value from command output and avoids persisting it in plans and state.

If `terraform.tfvars` does not exist, recreate it from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

## 2. Use dashboard-specific commands

### Upgrade from the legacy single-dashboard layout

If the current checkout already has a root-level `terraform.tfstate`, migrate the state after pulling the directory restructuring changes:

```bash
make migrate-intake-error
make init-intake-error
make plan-intake-error
```

The migration command includes these safeguards:

- If the destination state exists and the root state does not, it exits successfully because migration is already complete.
- If both the root and destination states exist, it fails immediately without overwriting either file.
- If Terraform currently holds a state lock, it fails immediately.
- It also migrates `terraform.tfstate.backup` without overwriting an existing backup.

The plan must report `No changes` before applying. If the legacy dashboard exists but its old state cannot be found, do not apply. Restore the state, configure a remote backend, or import the existing resources first.

The legacy root `terraform.tfvars` may also contain `dashboard_name`, `dashboard_tags`, `intake_path`, and `tenant_property`. These settings are now managed by `dashboards/intake-error/dashboard.tfvars.json`; remove them from the root file and retain only the three shared PostHog settings.

### Daily commands

The complete `intake-error` workflow is:

```bash
make init-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
make apply-intake-error
```

`intake-performance` manages the existing Overview dashboard and the new Diagnostics dashboard, with 31 insights and two layouts. Import all existing resources before the first apply. The complete ID mapping and commands are documented in [Intake Performance metrics and usage](./docs/intake-performance.md#8-importing-existing-resources). Bootstrap a new local state with:

```bash
make init-intake-performance
make import-intake-performance
```

After importing, use this regular workflow:

```bash
make fmt-check-intake-performance
make validate-intake-performance
make plan-intake-performance
make apply-intake-performance
```

Inspect output and state with:

```bash
make output-intake-error
make state-list-intake-error
make output-intake-performance
make state-list-intake-performance
```

For Intake Performance, `dashboard.tfvars.json` configures both dashboard names, the Overview and Diagnostics rolling ranges, tags, and the Intake path. `make output-intake-performance` returns the Overview ID/URL, Diagnostics ID/URL, and the complete Insight ID map. See the [Intake Performance management scope](./docs/intake-performance.md#7-terraform-management-scope) for the exact inputs, outputs, cleanup behavior, and provider limitations.

Always specify the dashboard explicitly when destroying resources:

```bash
make destroy-intake-error
```

The generic commands are equivalent:

```bash
make plan DASHBOARD=intake-error
make apply DASHBOARD=intake-error
```

`make apply-intake-error` reads only:

- Root `terraform.tfvars`: shared PostHog connection settings.
- `dashboards/intake-error/dashboard.tfvars.json`: business configuration for this dashboard.
- `dashboards/intake-error/terraform.tfstate`: independent local state for this dashboard.

## 3. Add a dashboard

1. Create an independent root module under `dashboards/<dashboard-name>/`.
2. Create `dashboard.tfvars.json` for the dashboard.
3. Register the name in `DASHBOARDS` in the root `Makefile`.
4. Run `make init-<dashboard-name>`, `make plan-<dashboard-name>`, and `make apply-<dashboard-name>` in order.

See [dashboards/README.md](./dashboards/README.md) ([Chinese](./dashboards/README.zh.md)) for detailed constraints. Do not use `-target` to create dashboards separately in a shared state, and never copy another dashboard's state.

## Security

- Root `terraform.tfvars`, Terraform state, and plan files are excluded by `.gitignore`.
- `dashboard.tfvars.json` may contain only non-sensitive business configuration.
- `terraform.tfvars.example` may contain placeholders only; never add a real API key.
- Terraform state may contain resource information. Use an encrypted remote backend in team environments.
- Never force-commit a Personal API Key, a state file, or execution logs containing sensitive values.
