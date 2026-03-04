#!/usr/bin/env bash
# orchestrator.sh - Run N x M experiment from experiment.yaml
#
# Reads config, validates environment, builds a run schedule (with optional
# interleaving), executes each run via runner.sh, then generates a report.
#
# Usage: framework/orchestrator.sh <experiment_dir> [--dry-run] [--runs N]

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FRAMEWORK_DIR/lib/validation.sh"
source "$FRAMEWORK_DIR/lib/git-isolation.sh"

EXPERIMENT_DIR="$(cd "${1:?Usage: orchestrator.sh <experiment_dir> [--dry-run] [--runs N]}" && pwd)"
shift
DRY_RUN=""
RUNS_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="--dry-run"; shift ;;
    --runs) RUNS_OVERRIDE="${2:?--runs requires a number}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
CONFIG_FILE="$EXPERIMENT_DIR/experiment.yaml"

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
echo "=== Preflight checks ==="
validate_config "$CONFIG_FILE" "$EXPERIMENT_DIR"
validate_environment "$CONFIG_FILE"
echo "=== Preflight OK ==="
echo ""

# ---------------------------------------------------------------------------
# Read config
# ---------------------------------------------------------------------------
experiment_name=$(yq '.name' "$CONFIG_FILE")
per_condition=${RUNS_OVERRIDE:-$(yq '.runs.per_condition' "$CONFIG_FILE")}
interleave=$(yq '.runs.interleave // false' "$CONFIG_FILE")
num_conditions=$(yq '.conditions | length' "$CONFIG_FILE")
model=$(yq '.agent.model' "$CONFIG_FILE")
max_turns=$(yq '.agent.max_turns' "$CONFIG_FILE")
project_dir=$(eval echo "$(yq '.project.local_path' "$CONFIG_FILE")")
base_commit=$(yq '.project.base_commit' "$CONFIG_FILE")
setup_command=$(yq '.project.setup_command // ""' "$CONFIG_FILE")
total_runs=$(( num_conditions * per_condition ))

echo "============================================================"
echo "  AgentProbe: $experiment_name"
echo "  Model: $model | Max turns: $max_turns"
echo "  Conditions: $num_conditions | Runs/condition: $per_condition"
echo "  Total runs: $total_runs"
echo "  Interleave: $interleave"
echo "  Project: $project_dir"
echo "  Base commit: ${base_commit:0:12}"
[[ -n "$setup_command" && "$setup_command" != "null" ]] && \
  echo "  Setup: $setup_command"
echo "  Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Build run schedule
# ---------------------------------------------------------------------------
declare -a schedule  # "condition_index:run_number"

if [[ "$interleave" == "true" ]]; then
  # A-1, B-1, A-2, B-2, ... (balanced across time)
  for run in $(seq 1 "$per_condition"); do
    for ((ci = 0; ci < num_conditions; ci++)); do
      schedule+=("${ci}:${run}")
    done
  done
else
  # A-1, A-2, ..., B-1, B-2, ... (sequential blocks)
  for ((ci = 0; ci < num_conditions; ci++)); do
    for run in $(seq 1 "$per_condition"); do
      schedule+=("${ci}:${run}")
    done
  done
fi

echo "Run schedule (${#schedule[@]} runs):"
for entry in "${schedule[@]}"; do
  ci="${entry%%:*}"
  rn="${entry##*:}"
  cn=$(yq ".conditions[$ci].name" "$CONFIG_FILE")
  echo "  [$((ci + 1)):$rn] $cn"
done
echo ""

# ---------------------------------------------------------------------------
# Save experiment metadata
# ---------------------------------------------------------------------------
mkdir -p "$EXPERIMENT_DIR/results"
cat > "$EXPERIMENT_DIR/results/experiment-run.json" << METAEOF
{
  "experiment": "$(basename "$EXPERIMENT_DIR")",
  "name": "$experiment_name",
  "model": "$model",
  "max_turns": $max_turns,
  "per_condition": $per_condition,
  "num_conditions": $num_conditions,
  "interleave": $interleave,
  "base_commit": "$base_commit",
  "project_dir": "$project_dir",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
METAEOF

# Copy reference artifacts
cp "$EXPERIMENT_DIR/$(yq '.task.prompt_file' "$CONFIG_FILE")" \
   "$EXPERIMENT_DIR/results/task-prompt.reference" 2>/dev/null || true
cp "$CONFIG_FILE" "$EXPERIMENT_DIR/results/experiment.yaml.reference" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Execute schedule
# ---------------------------------------------------------------------------
completed=0

for entry in "${schedule[@]}"; do
  ci="${entry%%:*}"
  rn="${entry##*:}"
  completed=$((completed + 1))

  cn=$(yq ".conditions[$ci].name" "$CONFIG_FILE")
  echo ""
  echo "[$completed/$total_runs] $cn run $rn"

  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo "  [DRY RUN] Skipped"
    continue
  fi

  bash "$FRAMEWORK_DIR/runner.sh" "$EXPERIMENT_DIR" "$ci" "$rn"
done

# ---------------------------------------------------------------------------
# Generate report
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  echo ""
  echo "=== Generating report ==="
  bash "$FRAMEWORK_DIR/report-generator.sh" "$EXPERIMENT_DIR"
fi

echo ""
echo "============================================================"
echo "  Experiment complete: $experiment_name"
echo "  Results: $EXPERIMENT_DIR/results/"
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  echo "  Report:  $EXPERIMENT_DIR/results/report.md"
fi
echo "============================================================"
