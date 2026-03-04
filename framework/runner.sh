#!/usr/bin/env bash
# runner.sh - Execute a single agent session in an isolated worktree
#
# Reads experiment.yaml, creates a worktree, runs the agent,
# captures metrics, and cleans up.
#
# Usage: framework/runner.sh <experiment_dir> <condition_index> <run_number>
#
# Output: results/runs/<condition>/run-<N>/{metrics.json, session.json, changes.diff}

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FRAMEWORK_DIR/lib/git-isolation.sh"
source "$FRAMEWORK_DIR/lib/json-utils.sh"

EXPERIMENT_DIR="$(cd "${1:?Usage: runner.sh <experiment_dir> <condition_index> <run_number>}" && pwd)"
CONDITION_INDEX="${2:?Missing condition index}"
RUN_NUMBER="${3:?Missing run number}"

CONFIG_FILE="$EXPERIMENT_DIR/experiment.yaml"

# ---------------------------------------------------------------------------
# Read config
# ---------------------------------------------------------------------------
cond_name=$(yq ".conditions[$CONDITION_INDEX].name" "$CONFIG_FILE")
cond_setup=$(yq ".conditions[$CONDITION_INDEX].setup" "$CONFIG_FILE")
project_dir=$(eval echo "$(yq '.project.local_path' "$CONFIG_FILE")")
base_commit=$(yq '.project.base_commit' "$CONFIG_FILE")
agent_cli=$(yq '.agent.cli' "$CONFIG_FILE")
model=$(yq '.agent.model' "$CONFIG_FILE")
max_turns=$(yq '.agent.max_turns' "$CONFIG_FILE")
output_format=$(yq '.agent.output_format // "stream-json"' "$CONFIG_FILE")
prompt_file="$EXPERIMENT_DIR/$(yq '.task.prompt_file' "$CONFIG_FILE")"

extra_flags=()
while IFS= read -r flag; do
  [[ -n "$flag" ]] && extra_flags+=("$flag")
done < <(yq '.agent.extra_flags[]' "$CONFIG_FILE" 2>/dev/null)

# Verification commands (optional)
test_command=$(yq '.task.verification.test_command // ""' "$CONFIG_FILE")
typecheck_command=$(yq '.task.verification.typecheck_command // ""' "$CONFIG_FILE")
test_parser=$(yq '.task.verification.test_parser // "vitest"' "$CONFIG_FILE")

# Timeouts (seconds) — prevents hung verification from blocking the experiment
verification_timeout=$(yq '.task.verification.timeout // 600' "$CONFIG_FILE")
agent_timeout=$(yq '.agent.timeout // 3600' "$CONFIG_FILE")

# ---------------------------------------------------------------------------
# Output paths
# ---------------------------------------------------------------------------
run_label="${cond_name}-run-${RUN_NUMBER}"
results_run_dir="$EXPERIMENT_DIR/results/runs/${cond_name}/run-${RUN_NUMBER}"
mkdir -p "$results_run_dir"

log_file="$results_run_dir/session.json"
diff_file="$results_run_dir/changes.diff"
metrics_file="$results_run_dir/metrics.json"

echo ""
echo "================================================================"
echo "  Condition: $cond_name | Run: $RUN_NUMBER"
echo "================================================================"

# ---------------------------------------------------------------------------
# 1. Create isolated worktree
# ---------------------------------------------------------------------------
worktree_dir=$(create_worktree "$project_dir" "$base_commit" "$run_label")
echo "  Worktree: $worktree_dir"

# Ensure cleanup on exit
trap 'cleanup_worktree "$project_dir" "$worktree_dir"' EXIT

# ---------------------------------------------------------------------------
# 2. Run project setup (install dependencies, etc.)
# ---------------------------------------------------------------------------
setup_command=$(yq '.project.setup_command // ""' "$CONFIG_FILE")
setup_timeout=$(yq '.project.setup_timeout // "'"$verification_timeout"'"' "$CONFIG_FILE")
if [[ -n "$setup_command" && "$setup_command" != "null" ]]; then
  echo "  Running project setup (timeout ${setup_timeout}s)..."
  setup_exit=0
  (cd "$worktree_dir" && timeout "$setup_timeout" \
    bash -c "eval '$setup_command'" > /dev/null) || setup_exit=$?
  if [[ $setup_exit -eq 124 ]]; then
    echo "  ERROR: Project setup timed out after ${setup_timeout}s" >&2
    exit 1
  elif [[ $setup_exit -ne 0 ]]; then
    echo "  ERROR: Project setup failed (exit $setup_exit)" >&2
    exit 1
  fi
  echo "  Project setup complete."
fi

# ---------------------------------------------------------------------------
# 3. Run condition setup
# ---------------------------------------------------------------------------
setup_script="$EXPERIMENT_DIR/$cond_setup"
bash "$setup_script" "$worktree_dir"

# ---------------------------------------------------------------------------
# 4. Read task prompt
# ---------------------------------------------------------------------------
task_prompt=$(cat "$prompt_file")

# ---------------------------------------------------------------------------
# 5. Run agent
# ---------------------------------------------------------------------------
start_time=$(date +%s%3N)

echo "  Starting $agent_cli (model=$model, max-turns=$max_turns, timeout=${agent_timeout}s)..."

agent_exit_code=0
(
  cd "$worktree_dir"
  timeout "$agent_timeout" \
    "$agent_cli" -p "$task_prompt" \
    --model "$model" \
    --max-turns "$max_turns" \
    --output-format "$output_format" \
    "${extra_flags[@]}" \
    < /dev/null 2>&1
) > "$log_file" || agent_exit_code=$?

if [[ $agent_exit_code -eq 124 ]]; then
  echo "  TIMEOUT: Agent killed after ${agent_timeout}s"
fi

end_time=$(date +%s%3N)
duration_ms=$(( end_time - start_time ))

echo "  Duration: ${duration_ms}ms (~$(( duration_ms / 1000 / 60 )) min)"
echo "  Agent exit code: $agent_exit_code"

# ---------------------------------------------------------------------------
# 6. Capture diff
# ---------------------------------------------------------------------------
(cd "$worktree_dir" && git diff "$base_commit" > "$diff_file" 2>/dev/null) || true

# ---------------------------------------------------------------------------
# 7. Run verification (tests, typecheck)
# ---------------------------------------------------------------------------
test_exit_code=0
tests_passed=0
tests_failed=0
typecheck_exit=0
test_output=""

if [[ -n "$test_command" && "$test_command" != "null" ]]; then
  echo "  Running tests (timeout ${verification_timeout}s)..."
  test_output=$(cd "$worktree_dir" && timeout "$verification_timeout" \
    bash -c "AGENTPROBE_BASE_COMMIT='$base_commit' eval '$test_command'") || test_exit_code=$?

  if [[ $test_exit_code -eq 124 ]]; then
    echo "  TIMEOUT: Tests killed after ${verification_timeout}s"
  fi

  # Parse test results based on test_parser
  case "$test_parser" in
    vitest|jest)
      tests_passed=$(echo "$test_output" | grep -oP '\d+(?= passed)' | tail -1 || true)
      tests_failed=$(echo "$test_output" | grep -oP '\d+(?= failed)' | tail -1 || true)
      ;;
  esac
  tests_passed=${tests_passed:-0}
  tests_failed=${tests_failed:-0}
  echo "  Tests: $tests_passed passed, $tests_failed failed"
fi

if [[ -n "$typecheck_command" && "$typecheck_command" != "null" ]]; then
  echo "  Running typecheck (timeout ${verification_timeout}s)..."
  (cd "$worktree_dir" && timeout "$verification_timeout" \
    bash -c "eval '$typecheck_command'" > /dev/null 2>&1) || typecheck_exit=$?

  if [[ $typecheck_exit -eq 124 ]]; then
    echo "  TIMEOUT: Typecheck killed after ${verification_timeout}s"
  else
    echo "  Typecheck exit: $typecheck_exit"
  fi
fi

# ---------------------------------------------------------------------------
# 8. Extract metrics from log
# ---------------------------------------------------------------------------
extracted=$(bash "$FRAMEWORK_DIR/metrics-collector.sh" "$log_file")
input_tokens=$(echo "$extracted" | jq '.input_tokens')
output_tokens=$(echo "$extracted" | jq '.output_tokens')
cache_read=$(echo "$extracted" | jq '.cache_read_input_tokens')
cache_create=$(echo "$extracted" | jq '.cache_creation_input_tokens')
total_tokens=$(echo "$extracted" | jq '.total_tokens')
tool_calls=$(echo "$extracted" | jq '.tool_calls')

# ---------------------------------------------------------------------------
# 9. Diff stats
# ---------------------------------------------------------------------------
files_changed=0
insertions=0
deletions=0
if [[ -s "$diff_file" ]]; then
  files_changed=$(cd "$worktree_dir" && git diff --stat "$base_commit" | tail -1 | grep -oP '^\s*\K\d+' || true)
  insertions=$(cd "$worktree_dir" && git diff --numstat "$base_commit" | awk '{s+=$1} END {print s+0}' || true)
  deletions=$(cd "$worktree_dir" && git diff --numstat "$base_commit" | awk '{s+=$2} END {print s+0}' || true)
  files_changed=${files_changed:-0}
  insertions=${insertions:-0}
  deletions=${deletions:-0}
fi

# ---------------------------------------------------------------------------
# 10. Commit info
# ---------------------------------------------------------------------------
has_commit=false
commit_hash=""
commit_msg=""
if [[ "$(cd "$worktree_dir" && git rev-parse HEAD)" != "$base_commit" ]]; then
  has_commit=true
  commit_hash=$(cd "$worktree_dir" && git rev-parse HEAD)
  commit_msg=$(cd "$worktree_dir" && git log -1 --pretty=format:"%s" 2>/dev/null || echo "")
fi

# ---------------------------------------------------------------------------
# 11. Write metrics.json
# ---------------------------------------------------------------------------
json_create_metrics "$metrics_file" \
  "experiment=$(basename "$EXPERIMENT_DIR")" \
  "condition=$cond_name" \
  "run=$RUN_NUMBER" \
  "model=$model" \
  "base_commit=$base_commit" \
  "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "duration_ms=$duration_ms" \
  "agent_exit_code=$agent_exit_code" \
  "input_tokens=$input_tokens" \
  "output_tokens=$output_tokens" \
  "cache_read_input_tokens=$cache_read" \
  "cache_creation_input_tokens=$cache_create" \
  "total_tokens=$total_tokens" \
  "tool_calls=$tool_calls" \
  "tests_passed=$tests_passed" \
  "tests_failed=$tests_failed" \
  "test_exit_code=$test_exit_code" \
  "typecheck_exit_code=$typecheck_exit" \
  "has_commit=$has_commit" \
  "commit_hash=$commit_hash" \
  "commit_message=$commit_msg" \
  "files_changed=$files_changed" \
  "insertions=$insertions" \
  "deletions=$deletions"

echo "  Metrics: $metrics_file"

# Cleanup happens via trap
