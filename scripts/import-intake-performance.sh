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
expected_project_id=92499
dashboard_dir="$project_root/dashboards/intake-performance"
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
    echo "The hard-coded intake-performance import map is only valid for PostHog project $expected_project_id." >&2
    echo "Current PostHog project: $project_id" >&2
    echo "Do not import these resource IDs into another project." >&2
    exit 1
fi

if [ ! -d "$dashboard_dir/.terraform" ]; then
    echo "Terraform is not initialized for intake-performance." >&2
    echo "Run: make init-intake-performance" >&2
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

    echo "Importing: $address <- $remote_id"
    "$terraform_bin" -chdir="$dashboard_dir" import \
        -var-file="$common_tfvars" \
        -var-file="$dashboard_tfvars" \
        "$address" \
        "$remote_id"
}

import_resource 'posthog_dashboard.intake_performance' '1956103'
import_resource 'posthog_dashboard.intake_performance_diagnostics' '1961465'
import_resource 'posthog_insight.intake_performance["derived_intake_lcp_slow_load_ratio"]' '10761331'
import_resource 'posthog_insight.intake_performance["intake_inp_p75_web_analytics"]' '10790939'
import_resource 'posthog_insight.intake_performance["intake_lcp_p75_web_analytics"]' '10790992'
import_resource 'posthog_insight.intake_performance["intake_fcp_p75_web_analytics"]' '10791107'
import_resource 'posthog_insight.intake_performance["intake_cls_p75_web_analytics"]' '10791201'
import_resource 'posthog_insight.intake_performance["intake_inp_p75_p90_p99"]' '10761218'
import_resource 'posthog_insight.intake_performance["intake_lcp_p75_p90_p99"]' '10761203'
import_resource 'posthog_insight.intake_performance["intake_fcp_p75_p90_p99"]' '10761205'
import_resource 'posthog_insight.intake_performance["intake_cls_p75_p90_p99"]' '10761220'
import_resource 'posthog_insight.intake_performance["intake_pv_total_web_analytics"]' '10791974'
import_resource 'posthog_insight.intake_performance["intake_uv_total_web_analytics"]' '10791894'
import_resource 'posthog_insight.intake_performance["intake_pv_trend_web_analytics"]' '10791526'
import_resource 'posthog_insight.intake_performance["intake_uv_trend_web_analytics"]' '10791435'
import_resource 'posthog_insight.intake_performance_overview_quality["intake_poor_inp_ratio"]' '10794623'
import_resource 'posthog_insight.intake_performance_overview_quality["intake_poor_fcp_ratio"]' '10794622'
import_resource 'posthog_insight.intake_performance_overview_quality["intake_poor_cls_ratio"]' '10794625'
import_resource 'posthog_insight.intake_performance_overview_quality["intake_web_vitals_coverage"]' '10794624'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_inp_p90_web_analytics"]' '10794932'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_lcp_p90_web_analytics"]' '10794927'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_fcp_p90_web_analytics"]' '10794930'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_cls_p90_web_analytics"]' '10794931'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_inp_p99_web_analytics"]' '10794934'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_lcp_p99_web_analytics"]' '10794928'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_fcp_p99_web_analytics"]' '10794929'
import_resource 'posthog_insight.intake_performance_overview_percentiles["intake_cls_p99_web_analytics"]' '10794933'
import_resource 'posthog_insight.intake_performance_overview_percentile_status' '10795642'
import_resource 'posthog_insight.intake_performance_diagnostics["intake_dimension_coverage"]' '10794610'
import_resource 'posthog_insight.intake_performance_diagnostics["intake_tenant_performance"]' '10794612'
import_resource 'posthog_insight.intake_performance_diagnostics["intake_org_performance"]' '10794613'
import_resource 'posthog_insight.intake_performance_diagnostics["intake_domain_performance"]' '10794611'
import_resource 'posthog_insight.intake_performance_diagnostics["intake_web_vitals_reports"]' '10795956'
import_resource 'posthog_dashboard_layout.intake_performance' '1956103'
import_resource 'posthog_dashboard_layout.intake_performance_diagnostics' '1961465'

echo "Import completed. Review the result with: make plan-intake-performance"
