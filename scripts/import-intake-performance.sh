#!/bin/sh

set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <project-root> [terraform-binary]" >&2
    exit 2
fi

project_root=$1
terraform_bin=${2:-terraform}
dashboard_dir="$project_root/dashboards/intake-performance"
common_tfvars="$project_root/terraform.tfvars"
dashboard_tfvars="$dashboard_dir/dashboard.tfvars.json"

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
