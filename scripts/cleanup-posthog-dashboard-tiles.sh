#!/bin/sh

set -eu

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <posthog-host> <project-id> <dashboard-id> <insight-id>..." >&2
    exit 2
fi

posthog_host=${1%/}
project_id=$2
dashboard_id=$3
shift 3

: "${POSTHOG_API_KEY:?POSTHOG_API_KEY must be set}"

dashboard_response=$(mktemp)
trap 'rm -f "$dashboard_response"' EXIT HUP INT TERM

curl -fsS \
    -H "Authorization: Bearer $POSTHOG_API_KEY" \
    "$posthog_host/api/projects/$project_id/dashboards/$dashboard_id/" \
    -o "$dashboard_response"

for insight_id in "$@"; do
    case "$insight_id" in
        *[!0-9]*|'')
            echo "Invalid insight ID: $insight_id" >&2
            exit 2
            ;;
    esac

    jq -r --argjson insight_id "$insight_id" \
        '.tiles[] | select(.insight.id == $insight_id) | .id' \
        "$dashboard_response" |
        while IFS= read -r tile_id; do
            case "$tile_id" in
                *[!0-9]*|'')
                    echo "Invalid tile ID: $tile_id" >&2
                    exit 2
                    ;;
            esac

            curl -fsS -X POST \
                -H "Authorization: Bearer $POSTHOG_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"tile_id\":$tile_id}" \
                "$posthog_host/api/projects/$project_id/dashboards/$dashboard_id/delete_tile/" \
                -o /dev/null

            echo "Removed dashboard tile $tile_id for insight $insight_id"
        done
done
