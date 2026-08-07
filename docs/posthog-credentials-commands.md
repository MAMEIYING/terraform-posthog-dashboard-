# Terraform Commands After Updating PostHog Project Credentials

> English | [中文](./posthog-credentials-commands.zh.md)

This guide explains how to use project-scoped Terraform workspaces after updating `posthog_project_id` and `posthog_api_key` for the PostHog dashboards managed by this repository.

## 1. Update the shared connection settings

Update the Git-ignored `terraform.tfvars` file in the project root:

```hcl
posthog_project_id = "new project ID"
posthog_api_key    = "new Personal API Key"
posthog_host       = "https://us.posthog.com"
```

The API key must have access to the target project. Never commit or print the real key. Restrict local access to the configuration file:

```bash
chmod 600 terraform.tfvars
```

If the file does not exist, create it from the example before filling in the real values with an editor:

```bash
cp terraform.tfvars.example terraform.tfvars
```

The Makefile reads `posthog_project_id` from this file and binds every stateful command to `project-<posthog_project_id>`. For example, project `341180` automatically uses `project-341180`. Commands do not depend on the interactively selected workspace.

## 2. Initialize and prepare the project workspace

Run all commands from the project root. Each dashboard root module needs its own project workspace with the same derived name.

### Intake Error

```bash
make init-intake-error
make workspace-list-intake-error
make workspace-new-intake-error   # Run once only when project-<ID> is missing
make workspace-show-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
```

### Intake Performance

```bash
make init-intake-performance
make workspace-list-intake-performance
make workspace-new-intake-performance   # Run once only when project-<ID> is missing
make workspace-show-intake-performance
make fmt-check-intake-performance
make validate-intake-performance
make plan-intake-performance
```

If the derived workspace is missing, `plan`, `apply`, `destroy`, `output`, `state-list`, and `import-intake-performance` fail with the corresponding `workspace-new` command. They never fall back to `default` or reuse another project's State.

## 3. Review the plan and decide whether to apply

- If the plan reports `No changes`, the resources in the target project match the Terraform configuration and no apply is necessary.
- If the plan contains only expected changes, review the create, update, and delete counts before applying each dashboard separately.
- If a `401`, `403`, or `404` error occurs, verify the Project ID, Personal API Key permissions, and PostHog host.
- If the plan proposes recreating or deleting many resources, stop and inspect the State in the project workspace.

After confirming that the plans are expected, run:

```bash
make apply-intake-error
make apply-intake-performance
```

After applying, inspect the dashboard outputs and State:

```bash
make output-intake-error
make state-list-intake-error
make output-intake-performance
make state-list-intake-performance
```

## 4. Switch or add a PostHog project

Changing `posthog_project_id` changes the project workspace selected by the Makefile; it does not migrate resources from the previous project.

- **New empty project:** Create each dashboard's workspace once, review the create plan, and then apply.
- **Existing resources in the target project:** Create the project workspace and import the target project's real resource IDs before applying.
- **Legacy local State:** `make migrate-<dashboard-name>` moves root-level or dashboard `default` State into the current `project-<ID>`. It refuses to continue when source and target both exist or when State is locked.

The fixed resource map in `make import-intake-performance` is valid only for PostHog project `92499`. The script refuses to run for another project or a mismatched workspace.
