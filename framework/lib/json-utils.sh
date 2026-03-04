#!/usr/bin/env bash
# json-utils.sh - JSON construction helpers using jq
#
# Provides: json_create_metrics, json_merge_metrics

# Build a metrics JSON from key=value pairs and write to file.
# Detects types: numbers, booleans, strings.
# Usage: json_create_metrics output.json key1=val1 key2=val2 ...
json_create_metrics() {
  local output_file="$1"
  shift

  local json="{}"
  for pair in "$@"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"

    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      json=$(echo "$json" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
    elif [[ "$value" == "true" || "$value" == "false" ]]; then
      json=$(echo "$json" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
    else
      json=$(echo "$json" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    fi
  done

  echo "$json" | jq '.' > "$output_file"
}

# Merge all metrics.json files under a results directory into a JSON array.
# Usage: json_merge_metrics results_dir > aggregated.json
json_merge_metrics() {
  local results_dir="$1"
  find "$results_dir" -name "metrics.json" -path "*/runs/*" | sort | \
    xargs cat | jq -s '.'
}
