#!/usr/bin/env bash
# report-generator.sh - Generate markdown report from experiment results
#
# Thin wrapper around report_generator.py. Resolves the experiment directory
# and delegates all computation to Python.
#
# Usage: framework/report-generator.sh <experiment_dir>
# Output: <experiment_dir>/results/report.md, <experiment_dir>/results/summary.json

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(cd "${1:?Usage: report-generator.sh <experiment_dir>}" && pwd)"

python3 "$FRAMEWORK_DIR/report_generator.py" "$EXPERIMENT_DIR"

echo ""
echo "Report: $EXPERIMENT_DIR/results/report.md"
echo "Summary: $EXPERIMENT_DIR/results/summary.json"
