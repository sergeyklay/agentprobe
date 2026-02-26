#!/usr/bin/env bash
# =============================================================================
# Recalculate token metrics from existing stream-json logs
# Updates *_metrics.json files in-place without re-running experiments
# Usage: ./recalc-tokens.sh <results_dir>
# =============================================================================
set -euo pipefail

RESULTS_DIR="${1:?Usage: recalc-tokens.sh <results_dir>}"

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "ERROR: Results directory not found: $RESULTS_DIR"
  exit 1
fi

echo "=== Recalculating token metrics from logs ==="

for metrics_file in "$RESULTS_DIR"/*_metrics.json; do
  [[ -f "$metrics_file" ]] || continue

  log_file=$(python3 -c "import json; print(json.load(open('$metrics_file'))['log_file'])" 2>/dev/null || echo "")

  if [[ -z "$log_file" ]] || [[ ! -f "$log_file" ]]; then
    echo "  SKIP: $(basename "$metrics_file") - log file not found: $log_file"
    continue
  fi

  # Parse tokens from stream-json
  read -r input_tokens output_tokens tool_calls <<< "$(python3 -c "
import json

input_total = 0
output_total = 0
tool_call_count = 0

for line in open('$log_file'):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)

        # Count tool use
        if obj.get('type') == 'assistant' and 'message' in obj:
            msg = obj['message']
            for block in msg.get('content', []):
                if block.get('type') == 'tool_use':
                    tool_call_count += 1

        # Sum tokens from message.usage
        usage = None
        if obj.get('type') == 'assistant' and 'message' in obj:
            usage = obj['message'].get('usage')
        elif 'usage' in obj:
            usage = obj['usage']

        if usage:
            input_total += usage.get('input_tokens', 0)
            input_total += usage.get('cache_read_input_tokens', 0)
            input_total += usage.get('cache_creation_input_tokens', 0)
            output_total += usage.get('output_tokens', 0)
    except:
        pass

print(input_total, output_total, tool_call_count)
" 2>/dev/null || echo "0 0 0")"

  total_tokens=$(( input_tokens + output_tokens ))

  # Update the metrics JSON in-place
  python3 -c "
import json

with open('$metrics_file') as f:
    data = json.load(f)

data['input_tokens'] = $input_tokens
data['output_tokens'] = $output_tokens
data['total_tokens'] = $total_tokens
data['tool_calls'] = $tool_calls

with open('$metrics_file', 'w') as f:
    json.dump(data, f, indent=2)
"

  echo "  $(basename "$metrics_file"): input=$input_tokens output=$output_tokens total=$total_tokens tools=$tool_calls"
done

echo ""
echo "=== Done. Now re-run: bash generate-report.sh $RESULTS_DIR ==="
