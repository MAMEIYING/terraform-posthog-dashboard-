# Terraform Commands After Updating PostHog Project Credentials

> English | [中文](./posthog-credentials-commands.zh.md)

This guide explains how to validate and apply the PostHog dashboards managed by this repository after updating `posthog_project_id` and `posthog_api_key`.

## 1. Update the shared connection settings

Update the Git-ignored `terraform.tfvars` file in the project root:

```hcl
posthog_project_id = "new project ID"
posthog_api_key    = "new Personal API Key"
posthog_host       = "https://us.posthog.com"
```

The API key must be a PostHog Personal API Key with access to the target project. Never commit or print the real key. Restrict local access to the configuration file:

```bash
chmod 600 terraform.tfvars
```

If the file does not exist, create it from the example before filling in the real values with an editor:

```bash
cp terraform.tfvars.example terraform.tfvars
```

## 2. Initialize and validate both dashboards

Run all commands from the project root.

### Intake Error

```bash
make init-intake-error
make fmt-check-intake-error
make validate-intake-error
make plan-intake-error
```

### Intake Performance

```bash
make init-intake-performance
make fmt-check-intake-performance
make validate-intake-performance
make plan-intake-performance
```

## 3. Review the plan and decide whether to apply

- If the plan reports `No changes`, the resources in the target project match the Terraform configuration and no apply is necessary.
- If the plan contains only expected changes, review the resource create, update, and delete counts before applying each dashboard separately.
- If a `401`, `403`, or `404` error occurs, verify the Project ID, Personal API Key permissions, and PostHog host before continuing.
- If the plan proposes recreating or deleting many resources, stop and verify that the target project matches the local State.

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

## 4. New PostHog project considerations

The two dashboards in this repository use separate local State files. Changing `posthog_project_id` does not migrate resources from the previous project to the new project.

If the target is a new, empty PostHog project, do not apply with State that contains resource IDs from the previous project. Define an independent State strategy for the new project before creating resources. If equivalent resources already exist in the new project, import them instead of creating duplicates.
