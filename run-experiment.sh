#!/usr/bin/env bash
# =============================================================================
# CLAUDE.md Effect Experiment - Orchestrator
# =============================================================================
# Usage: ./run-experiment.sh [--runs N] [--project-dir DIR]
#
# Runs N headless Claude Code sessions for each condition (with/without CLAUDE.md)
# and generates a comparative report.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_PER_CONDITION=3
PROJECT_DIR="${PROJECT_DIR:-$HOME/work/typescript-eslint}"
RESULTS_DIR="$SCRIPT_DIR/results"
LOGS_DIR="$RESULTS_DIR/logs"
DIFFS_DIR="$RESULTS_DIR/diffs"
MODEL="claude-sonnet-4-5-20250929"
MAX_TURNS=50

usage() {
  echo "Usage: $0 [--runs N] [--project-dir DIR] [--model MODEL] [--max-turns N]"
  echo ""
  echo "Options:"
  echo "  --runs N           Number of runs per condition (default: $RUNS_PER_CONDITION)"
  echo "  --project-dir DIR  Path to the project git repository (default: $PROJECT_DIR)"
  echo "  --model MODEL      Claude model to use (default: $MODEL)"
  echo "  --max-turns N      Max turns for Claude session (default: $MAX_TURNS)"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --help) usage; exit 0 ;;
    --runs) RUNS_PER_CONDITION="$2"; shift 2 ;;
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    *) echo -e "Unknown arg: $1\n"; usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Derived paths
# ---------------------------------------------------------------------------
CLAUDE_MD_FILE="$SCRIPT_DIR/CLAUDE.md"
TASK_PROMPT_FILE="$SCRIPT_DIR/task-prompt.txt"
REPORT_GENERATOR="$SCRIPT_DIR/generate-report.sh"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
preflight() {
  echo "=== Preflight checks ==="

  # Check claude is available
  if ! command -v claude &>/dev/null; then
    echo "ERROR: 'claude' CLI not found. Install Claude Code first."
    exit 1
  fi
  echo "  claude: $(command -v claude)"

  # Check project dir
  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    echo "ERROR: $PROJECT_DIR is not a git repository."
    exit 1
  fi
  echo "  project: $PROJECT_DIR"

  # Check node via asdf
  if [[ -f "$PROJECT_DIR/.tool-versions" ]]; then
    echo "  .tool-versions found"
  fi

  # Verify node and pnpm are reachable from current PATH
  local node_path pnpm_path
  node_path=$(command -v node 2>/dev/null || true)
  pnpm_path=$(command -v pnpm 2>/dev/null || true)

  if [[ -z "$node_path" ]]; then
    echo "ERROR: node not in PATH. Source ~/.profile or configure asdf first."
    exit 1
  fi
  if [[ -z "$pnpm_path" ]]; then
    echo "ERROR: pnpm not in PATH. Source ~/.profile or configure asdf first."
    exit 1
  fi

  echo "  node: $node_path ($(node --version 2>/dev/null))"
  echo "  pnpm: $pnpm_path ($(pnpm --version 2>/dev/null))"

  # Check required files
  for f in "$CLAUDE_MD_FILE" "$TASK_PROMPT_FILE"; do
    if [[ ! -f "$f" ]]; then
      echo "ERROR: Required file not found: $f"
      exit 1
    fi
  done
  echo "  CLAUDE.md: $CLAUDE_MD_FILE"
  echo "  task prompt: $TASK_PROMPT_FILE"

  # Record base commit
  BASE_COMMIT=$(cd "$PROJECT_DIR" && git rev-parse HEAD)
  BASE_BRANCH=$(cd "$PROJECT_DIR" && git rev-parse --abbrev-ref HEAD)
  echo "  base commit: $BASE_COMMIT"
  echo "  base branch: $BASE_BRANCH"

  # Check settings.json symlink
  if [[ -L "$HOME/.claude/settings.json" ]]; then
    echo "  settings.json: $(readlink -f "$HOME/.claude/settings.json")"
  elif [[ -f "$HOME/.claude/settings.json" ]]; then
    echo "  settings.json: $HOME/.claude/settings.json (regular file)"
  else
    echo "  WARN: ~/.claude/settings.json not found"
  fi

  # Create output dirs
  mkdir -p "$LOGS_DIR" "$DIFFS_DIR"

  echo "=== Preflight OK ==="
  echo ""
}

# ---------------------------------------------------------------------------
# Clean git state - reset to base commit, remove CLAUDE.md if present
# ---------------------------------------------------------------------------
reset_repo() {
  cd "$PROJECT_DIR"
  git checkout "$BASE_BRANCH" --force 2>/dev/null || git checkout --detach "$BASE_COMMIT" --force
  git reset --hard "$BASE_COMMIT"
  git clean -fd
  rm -f "$PROJECT_DIR/CLAUDE.md"
}

# ---------------------------------------------------------------------------
# Run a single agent session
# ---------------------------------------------------------------------------
# Args: $1=condition (with|without), $2=run_number
run_single() {
  local condition="$1"
  local run_num="$2"
  local branch_name="experiment/${condition}-claude-md/run-${run_num}"
  local log_file="$LOGS_DIR/${condition}_run${run_num}.json"
  local diff_file="$DIFFS_DIR/${condition}_run${run_num}.diff"
  local metrics_file="$RESULTS_DIR/${condition}_run${run_num}_metrics.json"

  echo ""
  echo "================================================================"
  echo "  Condition: $condition | Run: $run_num | Branch: $branch_name"
  echo "================================================================"

  # 1. Reset repo
  reset_repo

  # 2. Create branch
  cd "$PROJECT_DIR"
  git checkout -b "$branch_name"

  # 3. If "with" condition, copy CLAUDE.md
  if [[ "$condition" == "with" ]]; then
    cp "$CLAUDE_MD_FILE" "$PROJECT_DIR/CLAUDE.md"
    echo "  CLAUDE.md placed in project root"
  fi

  # 4. Configure git for anonymous commits (no gpg)
  cd "$PROJECT_DIR"
  git config user.email "experiment@localhost"
  git config user.name "Experiment Agent"
  git config commit.gpgsign false

  # 5. Read task prompt
  local task_prompt
  task_prompt=$(cat "$TASK_PROMPT_FILE")

  # 6. Record start time
  local start_time
  start_time=$(date +%s%3N)

  # 7. Run Claude Code headless
  echo "  Starting claude -p (model=$MODEL, max-turns=$MAX_TURNS)..."

  local claude_exit_code=0
  (
    cd "$PROJECT_DIR"
    claude -p "$task_prompt" \
      --model "$MODEL" \
      --max-turns "$MAX_TURNS" \
      --output-format stream-json \
      --dangerously-skip-permissions \
      --verbose \
      2>&1
  ) > "$log_file" || claude_exit_code=$?

  # 8. Record end time
  local end_time
  end_time=$(date +%s%3N)
  local duration_ms=$(( end_time - start_time ))

  echo "  Duration: ${duration_ms}ms (~$(( duration_ms / 1000 / 60 )) min)"
  echo "  Exit code: $claude_exit_code"

  # 9. Capture diff
  cd "$PROJECT_DIR"
  git diff "$BASE_COMMIT" > "$diff_file" 2>/dev/null || true

  # 10. Extract metrics from stream-json log
  local tool_calls=0
  local input_tokens=0
  local output_tokens=0
  local result_text=""

  if [[ -f "$log_file" ]]; then
    # Count tool calls from stream-json
    tool_calls=$(grep -c '"type":"tool_use"' "$log_file" 2>/dev/null || echo "0")

    # Sum tokens from assistant message usage blocks
    # stream-json puts usage inside {"type":"assistant","message":{...,"usage":{...}}}
    read -r input_tokens output_tokens <<< "$(python3 -c "
import sys, json

input_total = 0
output_total = 0

for line in open('$log_file'):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        # Tokens live in message.usage for type=assistant events
        usage = None
        if obj.get('type') == 'assistant' and 'message' in obj:
            usage = obj['message'].get('usage')
        # Also check top-level usage (some stream-json formats)
        elif 'usage' in obj:
            usage = obj['usage']

        if usage:
            input_total += usage.get('input_tokens', 0)
            input_total += usage.get('cache_read_input_tokens', 0)
            input_total += usage.get('cache_creation_input_tokens', 0)
            output_total += usage.get('output_tokens', 0)
    except:
        pass

print(input_total, output_total)
" 2>/dev/null || echo "0 0")"
    input_tokens=${input_tokens:-0}
    output_tokens=${output_tokens:-0}

    # Extract final result text
    result_text=$(tail -20 "$log_file" | grep '"type":"result"' 2>/dev/null | \
      python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'result':
            print(obj.get('result', '')[:500])
    except: pass
" 2>/dev/null || echo "")
  fi

  # 11. Run tests to check results
  echo "  Running tests..."
  local test_exit_code=0
  local test_output=""
  cd "$PROJECT_DIR"

  test_output=$(
    cd "$PROJECT_DIR"
    # Identify which test file to run based on changed files
    local changed_rule
    changed_rule=$(git diff --name-only "$BASE_COMMIT" | grep 'packages/eslint-plugin/src/rules/' | head -1 | xargs basename 2>/dev/null | sed 's/\.ts$//' || echo "")

    if [[ -n "$changed_rule" ]] && [[ -f "packages/eslint-plugin/tests/rules/${changed_rule}.test.ts" ]]; then
      npx vitest run "packages/eslint-plugin/tests/rules/${changed_rule}.test.ts" 2>&1
    else
      # Fallback: run all eslint-plugin tests (slower)
      npx vitest run packages/eslint-plugin/tests/ 2>&1
    fi
  ) || test_exit_code=$?

  # 12. Count passed/failed tests
  local tests_passed=0
  local tests_failed=0
  local tests_total=0

  # Parse vitest output
  if echo "$test_output" | grep -q "Tests"; then
    tests_passed=$(echo "$test_output" | grep -oP '\d+(?= passed)' | tail -1 2>/dev/null || true)
    tests_failed=$(echo "$test_output" | grep -oP '\d+(?= failed)' | tail -1 2>/dev/null || true)
    tests_passed=${tests_passed:-0}
    tests_failed=${tests_failed:-0}
    tests_total=$(( tests_passed + tests_failed ))
  fi

  echo "  Tests: $tests_passed passed, $tests_failed failed (total: $tests_total)"

  # 13. Run typecheck
  echo "  Running typecheck..."
  local typecheck_exit=0
  (
    cd "$PROJECT_DIR"
    npx tsc --noEmit -p packages/eslint-plugin/tsconfig.json 2>&1
  ) > /dev/null 2>&1 || typecheck_exit=$?

  echo "  Typecheck exit: $typecheck_exit"

  # 14. Check if there's a commit
  local commit_hash=""
  local commit_msg=""
  local has_commit=false
  if [[ "$(git rev-parse HEAD)" != "$BASE_COMMIT" ]]; then
    has_commit=true
    commit_hash=$(git rev-parse HEAD)
    commit_msg=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "")
  fi

  # 15. Get diff stats
  local files_changed=0
  local insertions=0
  local deletions=0
  if [[ -f "$diff_file" ]] && [[ -s "$diff_file" ]]; then
    files_changed=$(git diff --stat "$BASE_COMMIT" | tail -1 | grep -oP '^\s*\K\d+' 2>/dev/null || true)
    insertions=$(git diff --numstat "$BASE_COMMIT" | awk '{s+=$1} END {print s+0}' 2>/dev/null || true)
    deletions=$(git diff --numstat "$BASE_COMMIT" | awk '{s+=$2} END {print s+0}' 2>/dev/null || true)
    files_changed=${files_changed:-0}
    insertions=${insertions:-0}
    deletions=${deletions:-0}
  fi

  # 16. Write metrics JSON
  cat > "$metrics_file" <<METRICS_EOF
{
  "condition": "$condition",
  "run": $run_num,
  "branch": "$branch_name",
  "model": "$MODEL",
  "base_commit": "$BASE_COMMIT",
  "duration_ms": $duration_ms,
  "claude_exit_code": $claude_exit_code,
  "tool_calls": $tool_calls,
  "input_tokens": $input_tokens,
  "output_tokens": $output_tokens,
  "total_tokens": $(( input_tokens + output_tokens )),
  "tests_passed": $tests_passed,
  "tests_failed": $tests_failed,
  "tests_total": $tests_total,
  "test_exit_code": $test_exit_code,
  "typecheck_exit_code": $typecheck_exit,
  "has_commit": $has_commit,
  "commit_hash": "$commit_hash",
  "commit_message": "$(echo "$commit_msg" | sed 's/"/\\"/g')",
  "files_changed": $files_changed,
  "insertions": $insertions,
  "deletions": $deletions,
  "diff_file": "$diff_file",
  "log_file": "$log_file",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
METRICS_EOF

  echo "  Metrics saved to: $metrics_file"
  echo ""
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------
main() {
  echo "============================================================"
  echo "  CLAUDE.md Effect Experiment"
  echo "  Runs per condition: $RUNS_PER_CONDITION"
  echo "  Model: $MODEL"
  echo "  Max turns: $MAX_TURNS"
  echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "============================================================"
  echo ""

  preflight

  # Save experiment config
  cat > "$RESULTS_DIR/experiment-config.json" <<CONFIG_EOF
{
  "runs_per_condition": $RUNS_PER_CONDITION,
  "model": "$MODEL",
  "max_turns": $MAX_TURNS,
  "project_dir": "$PROJECT_DIR",
  "base_commit": "$BASE_COMMIT",
  "base_branch": "$BASE_BRANCH",
  "claude_md_file": "$CLAUDE_MD_FILE",
  "task_prompt_file": "$TASK_PROMPT_FILE",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CONFIG_EOF

  # Copy reference files
  cp "$CLAUDE_MD_FILE" "$RESULTS_DIR/CLAUDE.md.reference"
  cp "$TASK_PROMPT_FILE" "$RESULTS_DIR/task-prompt.reference"

  # Run all "without" conditions first, then "with"
  # This prevents any cross-contamination through git state
  echo ""
  echo "########################################"
  echo "#  CONDITION A: WITHOUT CLAUDE.md      #"
  echo "########################################"
  for i in $(seq 1 "$RUNS_PER_CONDITION"); do
    run_single "without" "$i"
  done

  echo ""
  echo "########################################"
  echo "#  CONDITION B: WITH CLAUDE.md         #"
  echo "########################################"
  for i in $(seq 1 "$RUNS_PER_CONDITION"); do
    run_single "with" "$i"
  done

  # Reset repo to original state
  reset_repo
  echo ""

  # Generate report
  echo "=== Generating report ==="
  bash "$REPORT_GENERATOR" "$RESULTS_DIR"

  echo ""
  echo "============================================================"
  echo "  Experiment complete!"
  echo "  Results: $RESULTS_DIR/"
  echo "  Report:  $RESULTS_DIR/report.md"
  echo "============================================================"
}

main
