#!/bin/sh

set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <project-root> <dashboard-name> <workspace-name>" >&2
    exit 2
fi

project_root=$1
dashboard_name=$2
workspace_name=$3
dashboard_dir="$project_root/dashboards/$dashboard_name"
root_state="$project_root/terraform.tfstate"
root_backup="$project_root/terraform.tfstate.backup"
root_lock="$project_root/.terraform.tfstate.lock.info"
default_state="$dashboard_dir/terraform.tfstate"
default_backup="$dashboard_dir/terraform.tfstate.backup"
default_lock="$dashboard_dir/.terraform.tfstate.lock.info"
target_dir="$dashboard_dir/terraform.tfstate.d/$workspace_name"
target_state="$target_dir/terraform.tfstate"
target_backup="$target_dir/terraform.tfstate.backup"
target_lock="$target_dir/.terraform.tfstate.lock.info"

case "$workspace_name" in
    "" | *[!A-Za-z0-9_-]*)
        echo "Invalid Terraform workspace name: $workspace_name" >&2
        exit 1
        ;;
esac

case "$workspace_name" in
    project-*) expected_project_id=${workspace_name#project-} ;;
    *)
        echo "Workspace name must use project-<posthog_project_id>: $workspace_name" >&2
        exit 1
        ;;
esac

case "$expected_project_id" in
    "" | *[!0-9]*)
        echo "Workspace project ID must contain digits only: $workspace_name" >&2
        exit 1
        ;;
esac

if [ ! -d "$dashboard_dir" ]; then
    echo "Dashboard directory does not exist: $dashboard_dir" >&2
    exit 1
fi

if [ -e "$root_lock" ] || [ -e "$default_lock" ] || [ -e "$target_lock" ]; then
    echo "Terraform State is locked. Stop the active Terraform command before migrating." >&2
    exit 1
fi

if [ -e "$root_state" ] && [ -e "$default_state" ]; then
    echo "Both root and dashboard-default State files exist; refusing to choose one automatically." >&2
    echo "Root: $root_state" >&2
    echo "Dashboard default: $default_state" >&2
    exit 1
fi

source_state=
source_backup=

if [ -e "$root_state" ]; then
    source_state=$root_state
    source_backup=$root_backup
elif [ -e "$default_state" ]; then
    source_state=$default_state
    source_backup=$default_backup
fi

if [ -e "$target_state" ]; then
    if [ -n "$source_state" ]; then
        echo "Both source and project-workspace State files exist; refusing to overwrite either file." >&2
        echo "Source: $source_state" >&2
        echo "Target: $target_state" >&2
        exit 1
    fi

    echo "State is already migrated: $target_state"
    exit 0
fi

if [ -z "$source_state" ]; then
    echo "Legacy State was not found at either supported location:" >&2
    echo "  $root_state" >&2
    echo "  $default_state" >&2
    echo "For an existing Dashboard, restore or import its State before running apply." >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to verify the PostHog project recorded in State." >&2
    exit 1
fi

state_project_ids=$(jq -r '[.resources[]?.instances[]?.attributes.project_id? // empty | tostring] | unique[]' "$source_state")

if [ -z "$state_project_ids" ]; then
    echo "Could not determine the PostHog project ID from source State; refusing to migrate it." >&2
    echo "Source: $source_state" >&2
    exit 1
fi

if [ "$(printf '%s\n' "$state_project_ids" | wc -l | tr -d ' ')" -ne 1 ]; then
    echo "Source State contains resources from multiple PostHog projects; refusing to migrate it." >&2
    printf 'Project IDs:\n%s\n' "$state_project_ids" >&2
    exit 1
fi

if [ "$state_project_ids" != "$expected_project_id" ]; then
    echo "Source State project does not match the target Workspace; refusing to migrate it." >&2
    echo "State project: $state_project_ids" >&2
    echo "Target workspace: $workspace_name" >&2
    exit 1
fi

if [ -e "$target_backup" ]; then
    echo "Target State backup already exists; refusing to overwrite or separate it from its State." >&2
    echo "Target backup: $target_backup" >&2
    exit 1
fi

mkdir -p "$target_dir"
mv "$source_state" "$target_state"

if [ -f "$source_backup" ]; then
    mv "$source_backup" "$target_backup"
fi

echo "State migrated successfully:"
echo "  $source_state"
echo "  -> $target_state"
echo
echo "Next steps:"
echo "  make init-$dashboard_name"
echo "  make workspace-show-$dashboard_name"
echo "  make plan-$dashboard_name"
echo "Only apply when the plan reports No changes for existing resources."
