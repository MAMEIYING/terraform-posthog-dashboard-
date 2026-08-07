#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <terraform-tfvars>" >&2
    exit 2
fi

tfvars_file=$1

if [ ! -f "$tfvars_file" ]; then
    exit 1
fi

awk -F= '
    /^[[:space:]]*posthog_project_id[[:space:]]*=/ {
        value = $2
        sub(/[[:space:]]*#.*/, "", value)
        gsub(/[[:space:]\"]/, "", value)
        print value
        found = 1
        exit
    }
    END {
        if (!found) {
            exit 1
        }
    }
' "$tfvars_file"
