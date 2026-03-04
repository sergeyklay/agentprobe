#!/usr/bin/env bash
# =============================================================================
# Generate experiment report from collected metrics
# Usage: ./generate-report.sh <results_dir>
# =============================================================================

set -euo pipefail

RESULTS_DIR="${1:?Usage: generate-report.sh <results_dir>}"
export RESULTS_DIR

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "ERROR: Results directory not found: $RESULTS_DIR"
  exit 1
fi

REPORT="$RESULTS_DIR/report.md"
CONFIG="$RESULTS_DIR/experiment-config.json"

# Read config
model=$(python3 -c "import json; print(json.load(open('$CONFIG'))['model'])" 2>/dev/null || echo "unknown")
base_commit=$(python3 -c "import json; print(json.load(open('$CONFIG'))['base_commit'])" 2>/dev/null || echo "unknown")
runs=$(python3 -c "import json; print(json.load(open('$CONFIG'))['runs_per_condition'])" 2>/dev/null || echo "3")
max_turns=$(python3 -c "import json; print(json.load(open('$CONFIG'))['max_turns'])" 2>/dev/null || echo "unknown")
started_at=$(python3 -c "import json; print(json.load(open('$CONFIG'))['started_at'])" 2>/dev/null || echo "unknown")

# Collect all metrics into a single JSON array for processing
python3 << 'PYEOF' > "$RESULTS_DIR/aggregated.json"
import json, glob, os, sys

results_dir = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("RESULTS_DIR", ".")
metrics_files = sorted(glob.glob(os.path.join(results_dir, "*_metrics.json")))

all_metrics = []
for f in metrics_files:
    with open(f) as fh:
        all_metrics.append(json.load(fh))

# Separate by condition
without = [m for m in all_metrics if m["condition"] == "without"]
with_cm = [m for m in all_metrics if m["condition"] == "with"]

def avg(lst, key):
    vals = [m[key] for m in lst if isinstance(m[key], (int, float))]
    return sum(vals) / len(vals) if vals else 0

def median(lst, key):
    vals = sorted([m[key] for m in lst if isinstance(m[key], (int, float))])
    n = len(vals)
    if n == 0: return 0
    if n % 2 == 1: return vals[n // 2]
    return (vals[n // 2 - 1] + vals[n // 2]) / 2

def stddev(lst, key):
    vals = [m[key] for m in lst if isinstance(m[key], (int, float))]
    if len(vals) < 2: return 0
    m = sum(vals) / len(vals)
    return (sum((x - m) ** 2 for x in vals) / (len(vals) - 1)) ** 0.5

report = {
    "all": all_metrics,
    "without": without,
    "with": with_cm,
    "summary": {
        "without": {
            "n": len(without),
            "duration_avg": avg(without, "duration_ms"),
            "duration_median": median(without, "duration_ms"),
            "duration_stddev": stddev(without, "duration_ms"),
            "tokens_avg": avg(without, "total_tokens"),
            "tokens_median": median(without, "total_tokens"),
            "tokens_stddev": stddev(without, "total_tokens"),
            "tool_calls_avg": avg(without, "tool_calls"),
            "tool_calls_median": median(without, "tool_calls"),
            "tests_passed_avg": avg(without, "tests_passed"),
            "tests_failed_avg": avg(without, "tests_failed"),
            "success_rate": sum(1 for m in without if m["test_exit_code"] == 0 and m["tests_failed"] == 0) / max(len(without), 1),
            "typecheck_pass_rate": sum(1 for m in without if m["typecheck_exit_code"] == 0) / max(len(without), 1),
            "commit_rate": sum(1 for m in without if m["has_commit"]) / max(len(without), 1),
        },
        "with": {
            "n": len(with_cm),
            "duration_avg": avg(with_cm, "duration_ms"),
            "duration_median": median(with_cm, "duration_ms"),
            "duration_stddev": stddev(with_cm, "duration_ms"),
            "tokens_avg": avg(with_cm, "total_tokens"),
            "tokens_median": median(with_cm, "total_tokens"),
            "tokens_stddev": stddev(with_cm, "total_tokens"),
            "tool_calls_avg": avg(with_cm, "tool_calls"),
            "tool_calls_median": median(with_cm, "tool_calls"),
            "tests_passed_avg": avg(with_cm, "tests_passed"),
            "tests_failed_avg": avg(with_cm, "tests_failed"),
            "success_rate": sum(1 for m in with_cm if m["test_exit_code"] == 0 and m["tests_failed"] == 0) / max(len(with_cm), 1),
            "typecheck_pass_rate": sum(1 for m in with_cm if m["typecheck_exit_code"] == 0) / max(len(with_cm), 1),
            "commit_rate": sum(1 for m in with_cm if m["has_commit"]) / max(len(with_cm), 1),
        }
    }
}

print(json.dumps(report, indent=2))
PYEOF

# Now generate the markdown report
python3 << 'PYEOF' > "$REPORT"
import json, sys, os

results_dir = os.environ.get("RESULTS_DIR", ".")
with open(os.path.join(results_dir, "aggregated.json")) as f:
    data = json.load(f)

with open(os.path.join(results_dir, "experiment-config.json")) as f:
    config = json.load(f)

s = data["summary"]
wo = s["without"]
wi = s["with"]

def fmt_ms(ms):
    secs = ms / 1000
    mins = int(secs // 60)
    secs_rem = secs % 60
    if mins > 0:
        return f"{mins}m {secs_rem:.0f}s"
    return f"{secs:.1f}s"

def fmt_tokens(t):
    if t >= 1000:
        return f"{t/1000:.1f}K"
    return str(int(t))

def delta_pct(a, b):
    if a == 0: return "N/A"
    pct = ((b - a) / a) * 100
    sign = "+" if pct > 0 else ""
    return f"{sign}{pct:.1f}%"

print("# Experiment Report: CLAUDE.md Effect on Agent Performance")
print()
print("## Objective")
print()
print("Test whether a well-crafted `CLAUDE.md` context file improves Claude Code agent")
print("performance when working on a real task in the `typescript-eslint` monorepo.")
print("This experiment addresses the claim from the ETH Zurich study (Gloaguen et al.,")
print("arXiv:2602.11988) that context files may hurt agent performance.")
print()
print("---")
print()
print("## Experimental Setup")
print()
print(f"| Variable | Value |")
print(f"|---|---|")
print(f"| Agent | Claude Code (headless, `-p` flag) |")
print(f"| Model | `{config['model']}` |")
print(f"| Max turns | {config['max_turns']} |")
print(f"| Runs per condition | {config['runs_per_condition']} |")
print(f"| Base commit | `{config['base_commit'][:12]}` |")
print(f"| Project | typescript-eslint/typescript-eslint |")
print(f"| Condition A | No CLAUDE.md |")
print(f"| Condition B | With CLAUDE.md (~45 lines, handcrafted) |")
print(f"| Started | {config['started_at']} |")
print()
print("**Task prompt:** Identical for both conditions (see `task-prompt.reference`).")
print()
print("**CLAUDE.md content:** See `CLAUDE.md.reference` in results directory.")
print()
print("---")
print()
print("## Results")
print()
print("### Summary Table")
print()
print(f"| Metric | Without CLAUDE.md | With CLAUDE.md | Delta |")
print(f"|---|---|---|---|")

# Duration
dur_delta = delta_pct(wo["duration_avg"], wi["duration_avg"])
print(f"| **Duration (avg)** | {fmt_ms(wo['duration_avg'])} | {fmt_ms(wi['duration_avg'])} | {dur_delta} |")
print(f"| Duration (median) | {fmt_ms(wo['duration_median'])} | {fmt_ms(wi['duration_median'])} | {delta_pct(wo['duration_median'], wi['duration_median'])} |")
print(f"| Duration (stddev) | {fmt_ms(wo['duration_stddev'])} | {fmt_ms(wi['duration_stddev'])} | - |")

# Tokens
tok_delta = delta_pct(wo["tokens_avg"], wi["tokens_avg"])
print(f"| **Total tokens (avg)** | {fmt_tokens(wo['tokens_avg'])} | {fmt_tokens(wi['tokens_avg'])} | {tok_delta} |")
print(f"| Tokens (median) | {fmt_tokens(wo['tokens_median'])} | {fmt_tokens(wi['tokens_median'])} | {delta_pct(wo['tokens_median'], wi['tokens_median'])} |")

# Tool calls
tc_delta = delta_pct(wo["tool_calls_avg"], wi["tool_calls_avg"])
print(f"| **Tool calls (avg)** | {wo['tool_calls_avg']:.1f} | {wi['tool_calls_avg']:.1f} | {tc_delta} |")

# Success metrics
print(f"| **Test success rate** | {wo['success_rate']*100:.0f}% | {wi['success_rate']*100:.0f}% | {delta_pct(wo['success_rate'], wi['success_rate']) if wo['success_rate'] > 0 else 'N/A'} |")
print(f"| Typecheck pass rate | {wo['typecheck_pass_rate']*100:.0f}% | {wi['typecheck_pass_rate']*100:.0f}% | - |")
print(f"| Commit rate | {wo['commit_rate']*100:.0f}% | {wi['commit_rate']*100:.0f}% | - |")

print()
print("### Per-Run Details")
print()

# Condition A
print("#### Condition A: Without CLAUDE.md")
print()
print(f"| Run | Duration | Tokens | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |")
print(f"|---|---|---|---|---|---|---|---|")
for m in data["without"]:
    tc_ok = "PASS" if m["typecheck_exit_code"] == 0 else "FAIL"
    cm = "Yes" if m["has_commit"] else "No"
    print(f"| {m['run']} | {fmt_ms(m['duration_ms'])} | {fmt_tokens(m['total_tokens'])} | {m['tool_calls']} | {m['tests_passed']} | {m['tests_failed']} | {tc_ok} | {cm} |")

print()

# Condition B
print("#### Condition B: With CLAUDE.md")
print()
print(f"| Run | Duration | Tokens | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |")
print(f"|---|---|---|---|---|---|---|---|")
for m in data["with"]:
    tc_ok = "PASS" if m["typecheck_exit_code"] == 0 else "FAIL"
    cm = "Yes" if m["has_commit"] else "No"
    print(f"| {m['run']} | {fmt_ms(m['duration_ms'])} | {fmt_tokens(m['total_tokens'])} | {m['tool_calls']} | {m['tests_passed']} | {m['tests_failed']} | {tc_ok} | {cm} |")

print()
print("---")
print()
print("## Analysis")
print()

# Duration analysis
if wi["duration_avg"] < wo["duration_avg"]:
    speedup = ((wo["duration_avg"] - wi["duration_avg"]) / wo["duration_avg"]) * 100
    print(f"### Speed: CLAUDE.md was {speedup:.0f}% faster")
elif wi["duration_avg"] > wo["duration_avg"]:
    slowdown = ((wi["duration_avg"] - wo["duration_avg"]) / wo["duration_avg"]) * 100
    print(f"### Speed: CLAUDE.md was {slowdown:.0f}% slower")
else:
    print("### Speed: No significant difference")
print()
print(f"Average duration without CLAUDE.md: {fmt_ms(wo['duration_avg'])} (stddev: {fmt_ms(wo['duration_stddev'])})")
print(f"Average duration with CLAUDE.md: {fmt_ms(wi['duration_avg'])} (stddev: {fmt_ms(wi['duration_stddev'])})")
print()

# Token analysis
if wi["tokens_avg"] < wo["tokens_avg"]:
    saving = ((wo["tokens_avg"] - wi["tokens_avg"]) / wo["tokens_avg"]) * 100
    print(f"### Tokens: CLAUDE.md used {saving:.0f}% fewer tokens")
else:
    extra = ((wi["tokens_avg"] - wo["tokens_avg"]) / wo["tokens_avg"]) * 100 if wo["tokens_avg"] > 0 else 0
    print(f"### Tokens: CLAUDE.md used {extra:.0f}% more tokens")
print()
print(f"Average tokens without CLAUDE.md: {fmt_tokens(wo['tokens_avg'])}")
print(f"Average tokens with CLAUDE.md: {fmt_tokens(wi['tokens_avg'])}")
print()

# Success analysis
print("### Task success")
print()
print(f"Without CLAUDE.md: {wo['success_rate']*100:.0f}% of runs had all tests passing")
print(f"With CLAUDE.md: {wi['success_rate']*100:.0f}% of runs had all tests passing")
print()

# Commit messages
print("### Commit messages")
print()
for m in data["all"]:
    if m["has_commit"]:
        print(f"- **{m['condition']} run {m['run']}:** `{m['commit_message']}`")
print()

print("---")
print()
print("## Conclusions")
print()
print("| Hypothesis | Result |")
print("|---|---|")

# Duration conclusion
if wi["duration_avg"] < wo["duration_avg"] * 0.85:
    print("| CLAUDE.md reduces time to solution | **Confirmed** |")
elif wi["duration_avg"] > wo["duration_avg"] * 1.15:
    print("| CLAUDE.md reduces time to solution | **Refuted** (slower) |")
else:
    print("| CLAUDE.md reduces time to solution | **Inconclusive** (within variance) |")

# Token conclusion
if wi["tokens_avg"] < wo["tokens_avg"] * 0.9:
    print("| CLAUDE.md reduces token usage | **Confirmed** |")
elif wi["tokens_avg"] > wo["tokens_avg"] * 1.1:
    print("| CLAUDE.md reduces token usage | **Refuted** (more tokens) |")
else:
    print("| CLAUDE.md reduces token usage | **Inconclusive** |")

# Quality conclusion
if wi["success_rate"] > wo["success_rate"]:
    print("| CLAUDE.md improves solution quality | **Supported** (higher success rate) |")
elif wi["success_rate"] < wo["success_rate"]:
    print("| CLAUDE.md improves solution quality | **Not supported** (lower success rate) |")
else:
    print("| CLAUDE.md improves solution quality | **Inconclusive** (equal success rate) |")

# Hurt performance
if wi["success_rate"] < wo["success_rate"] and wi["duration_avg"] > wo["duration_avg"]:
    print("| CLAUDE.md hurts performance (ETH Zurich claim) | **Partially supported** |")
else:
    print("| CLAUDE.md hurts performance (ETH Zurich claim) | **Not observed** |")

print()
print("---")
print()
print("## Reproducibility")
print()
print("All data needed to reproduce this experiment is in the results directory:")
print()
print("- `experiment-config.json` - experiment parameters")
print("- `CLAUDE.md.reference` - exact CLAUDE.md used")
print("- `task-prompt.reference` - exact prompt given to both agents")
print("- `*_metrics.json` - per-run quantitative data")
print("- `logs/` - full Claude Code stream-json session logs")
print("- `diffs/` - git diffs for each run")
print("- `aggregated.json` - combined metrics for analysis")
print()
print("## Appendix: Branch Information")
print()
for m in data["all"]:
    status = "PASS" if m["test_exit_code"] == 0 and m["tests_failed"] == 0 else "FAIL"
    ch = m["commit_hash"][:12] if m["commit_hash"] else "no commit"
    print(f"- `{m['branch']}` - {ch} - {status}")
PYEOF

echo "Report generated: $REPORT"
echo ""
cat "$REPORT"
