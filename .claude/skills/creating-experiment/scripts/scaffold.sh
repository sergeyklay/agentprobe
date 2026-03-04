#!/usr/bin/env bash
# scaffold.sh - Create experiment directory structure
#
# Usage: scaffold.sh <experiment-name> [base-dir]
#
# Detects next experiment number from existing experiments/ directory.
# Creates: experiment directory with conditions/ subdirectories.
#
# Example: scaffold.sh context-file-length experiments/
# Output:  experiments/002-context-file-length/

set -euo pipefail

EXPERIMENT_SLUG="${1:?Usage: scaffold.sh <experiment-name> [base-dir]}"
BASE_DIR="${2:-experiments}"

# Detect next number
last_num=0
if [[ -d "$BASE_DIR" ]]; then
  for dir in "$BASE_DIR"/[0-9][0-9][0-9]-*/; do
    [[ -d "$dir" ]] || continue
    num=$(basename "$dir" | grep -oP '^\d+' || true)
    num=$((10#$num))  # strip leading zeros
    [[ $num -gt $last_num ]] && last_num=$num
  done
fi
next_num=$(printf "%03d" $((last_num + 1)))

EXPERIMENT_DIR="${BASE_DIR}/${next_num}-${EXPERIMENT_SLUG}"

if [[ -d "$EXPERIMENT_DIR" ]]; then
  echo "ERROR: Directory already exists: $EXPERIMENT_DIR" >&2
  exit 1
fi

mkdir -p "$EXPERIMENT_DIR"
echo "$EXPERIMENT_DIR"
