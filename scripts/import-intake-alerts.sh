#!/bin/sh

set -eu

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <project-root> <terraform-binary> <workspace-name> <posthog-project-id>" >&2
    exit 2
fi

project_root=$1
terraform_bin=$2
workspace_name=$3
project_id=$4
expected_project_id=341180
dashboard_dir="$project_root/dashboards/intake-alerts"
common_tfvars="$project_root/terraform.tfvars"
dashboard_tfvars="$dashboard_dir/dashboard.tfvars.json"
project_id_reader="$project_root/scripts/read-posthog-project-id.sh"

case "$project_id" in
    "" | *[!0-9]*)
        echo "Invalid PostHog project ID: $project_id" >&2
        exit 1
        ;;
esac

if [ "$workspace_name" != "project-$project_id" ]; then
    echo "Workspace and PostHog project ID do not match." >&2
    echo "Expected workspace: project-$project_id" >&2
    echo "Received workspace: $workspace_name" >&2
    exit 1
fi

if [ "$project_id" != "$expected_project_id" ]; then
    echo "The hard-coded intake-alerts import map is only valid for PostHog project $expected_project_id." >&2
    echo "Current PostHog project: $project_id" >&2
    echo "Do not import these resource IDs into another project." >&2
    exit 1
fi

if [ ! -d "$dashboard_dir/.terraform" ]; then
    echo "Terraform is not initialized for intake-alerts." >&2
    echo "Run: make init-intake-alerts" >&2
    exit 1
fi

if [ ! -f "$common_tfvars" ]; then
    echo "Missing shared variables: $common_tfvars" >&2
    exit 1
fi

if [ ! -f "$dashboard_tfvars" ]; then
    echo "Missing dashboard variables: $dashboard_tfvars" >&2
    exit 1
fi

if [ ! -f "$project_id_reader" ]; then
    echo "Missing PostHog project ID reader: $project_id_reader" >&2
    exit 1
fi

if ! configured_project_id=$(sh "$project_id_reader" "$common_tfvars"); then
    echo "Unable to read posthog_project_id from $common_tfvars" >&2
    exit 1
fi

if [ "$configured_project_id" != "$project_id" ]; then
    echo "Configured PostHog project ID does not match the requested import project." >&2
    echo "terraform.tfvars: $configured_project_id" >&2
    echo "Requested: $project_id" >&2
    exit 1
fi

if ! "$terraform_bin" -chdir="$dashboard_dir" workspace list |
    awk -v wanted="$workspace_name" '{ sub(/^[* ]+/, "", $0); if ($0 == wanted) found = 1 } END { exit !found }'; then
    echo "Terraform workspace does not exist: $workspace_name" >&2
    echo "Create it before importing existing resources." >&2
    exit 1
fi

export TF_WORKSPACE="$workspace_name"

state_contains() {
    address=$1

    "$terraform_bin" -chdir="$dashboard_dir" state list 2>/dev/null |
        awk -v wanted="$address" '$0 == wanted { found = 1 } END { exit !found }'
}

import_resource() {
    address=$1
    remote_id=$2

    if state_contains "$address"; then
        echo "Already managed: $address"
        return
    fi

    echo "Importing: $address"
    "$terraform_bin" -chdir="$dashboard_dir" import \
        -var-file="$common_tfvars" \
        -var-file="$dashboard_tfvars" \
        "$address" \
        "$remote_id"
}

import_resource 'posthog_insight.intake_alert["p0_lcp"]' '10827279'
import_resource 'posthog_insight.intake_alert["warning_lcp"]' '10827280'
import_resource 'posthog_insight.intake_alert["frontend_error"]' '10827281'

import_resource 'restapi_object.intake_alert["p0_lcp"]' "/api/environments/$project_id/alerts/019fdb12-c134-0000-35e8-7bfaa38c20e8"
import_resource 'restapi_object.intake_alert["warning_lcp"]' "/api/environments/$project_id/alerts/019fdb12-c12f-0000-5cf7-140c110c7205"
import_resource 'restapi_object.intake_alert["frontend_error"]' "/api/environments/$project_id/alerts/019fdb12-c122-0000-3e43-a20d77a2e3fc"

import_resource 'posthog_hog_function.slack_alert["frontend_error_test_alert"]' '019fdb14-8f68-0000-a50b-98cdc1c866a3'
import_resource 'posthog_hog_function.slack_alert["p0_lcp_test_alert"]' '019fdb14-8e20-0000-fa19-c5803432b1d8'
import_resource 'posthog_hog_function.slack_alert["warning_lcp_test_alert"]' '019fdb14-8f52-0000-eafc-55fa37a63b62'
import_resource 'posthog_hog_function.slack_alert["frontend_error_staging"]' '019fdb14-8e1b-0000-a957-7cc5c68f2d05'
import_resource 'posthog_hog_function.slack_alert["p0_lcp_staging"]' '019fdb14-8e0a-0000-5772-446391cfc81d'
import_resource 'posthog_hog_function.slack_alert["warning_lcp_staging"]' '019fdb14-8e0d-0000-e1ba-3c3774b7bade'

echo "Import completed. Review the result with: make plan-intake-alerts"
