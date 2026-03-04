#!/usr/bin/env bash
# metrics-collector.sh - Extract metrics from Claude Code stream-json logs
#
# Outputs JSON to stdout with token counts (cache tracked separately),
# tool call count, and truncated result text.
#
# Usage: framework/metrics-collector.sh <log_file>
# Output: JSON on stdout

set -euo pipefail

LOG_FILE="${1:?Usage: metrics-collector.sh <log_file>}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo '{"error":"log file not found"}' >&2
  exit 1
fi

python3 << PYEOF
import json, sys

input_tokens = 0
output_tokens = 0
cache_read = 0
cache_create = 0
tool_calls = 0
result_text = ""

for line in open("$LOG_FILE"):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)

        # Count tool calls from assistant message content blocks
        if obj.get("type") == "assistant" and "message" in obj:
            for block in obj["message"].get("content", []):
                if block.get("type") == "tool_use":
                    tool_calls += 1

        # Extract usage — lives in message.usage or top-level usage
        usage = None
        if obj.get("type") == "assistant" and "message" in obj:
            usage = obj["message"].get("usage")
        elif "usage" in obj:
            usage = obj["usage"]

        if usage:
            input_tokens += usage.get("input_tokens", 0)
            cache_read += usage.get("cache_read_input_tokens", 0)
            cache_create += usage.get("cache_creation_input_tokens", 0)
            output_tokens += usage.get("output_tokens", 0)

        # Capture final result
        if obj.get("type") == "result":
            result_text = obj.get("result", "")[:500]
    except Exception:
        pass

json.dump({
    "input_tokens": input_tokens,
    "output_tokens": output_tokens,
    "cache_read_input_tokens": cache_read,
    "cache_creation_input_tokens": cache_create,
    "total_tokens": input_tokens + output_tokens + cache_read + cache_create,
    "tool_calls": tool_calls,
    "result_text": result_text
}, sys.stdout)
PYEOF
