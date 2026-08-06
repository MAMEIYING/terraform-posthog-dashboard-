#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <project-root> <dashboard-name>" >&2
    exit 2
fi

project_root=$1
dashboard_name=$2
dashboard_dir="$project_root/dashboards/$dashboard_name"
legacy_state="$project_root/terraform.tfstate"
legacy_backup="$project_root/terraform.tfstate.backup"
legacy_lock="$project_root/.terraform.tfstate.lock.info"
target_state="$dashboard_dir/terraform.tfstate"
target_backup="$dashboard_dir/terraform.tfstate.backup"
target_lock="$dashboard_dir/.terraform.tfstate.lock.info"

if [ ! -d "$dashboard_dir" ]; then
    echo "Dashboard directory does not exist: $dashboard_dir" >&2
    exit 1
fi

if [ -e "$legacy_lock" ] || [ -e "$target_lock" ]; then
    echo "Terraform State is locked. Stop the active Terraform command before migrating." >&2
    exit 1
fi

if [ -e "$target_state" ]; then
    if [ -e "$legacy_state" ]; then
        echo "Both legacy and target State files exist; refusing to overwrite either file." >&2
        echo "Legacy: $legacy_state" >&2
        echo "Target: $target_state" >&2
        exit 1
    fi

    echo "State is already migrated: $target_state"
    exit 0
fi

if [ ! -f "$legacy_state" ]; then
    echo "Legacy State was not found: $legacy_state" >&2
    echo "For an existing Dashboard, restore or import its State before running apply." >&2
    exit 1
fi

if [ -e "$target_backup" ] && [ -e "$legacy_backup" ]; then
    echo "Both legacy and target State backups exist; refusing to overwrite either file." >&2
    exit 1
fi

mv "$legacy_state" "$target_state"

if [ -f "$legacy_backup" ]; then
    mv "$legacy_backup" "$target_backup"
fi

echo "State migrated successfully:"
echo "  $legacy_state"
echo "  -> $target_state"
echo
echo "Next steps:"
echo "  make init-$dashboard_name"
echo "  make plan-$dashboard_name"
echo "Only apply when the plan reports No changes for existing resources."
