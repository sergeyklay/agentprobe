#!/usr/bin/env bash
# report-generator.sh - Generate markdown report from experiment results
#
# Reads experiment.yaml and per-run metrics.json files, computes statistics
# (mean, median, stddev, 95% CI, Cohen's d), and generates report.md.
#
# Usage: framework/report-generator.sh <experiment_dir>
# Output: <experiment_dir>/results/report.md, <experiment_dir>/results/summary.json

set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FRAMEWORK_DIR/lib/stats.sh"

EXPERIMENT_DIR="$(cd "${1:?Usage: report-generator.sh <experiment_dir>}" && pwd)"
CONFIG_FILE="$EXPERIMENT_DIR/experiment.yaml"
RESULTS_DIR="$EXPERIMENT_DIR/results"
REPORT="$RESULTS_DIR/report.md"
SUMMARY="$RESULTS_DIR/summary.json"

# ---------------------------------------------------------------------------
# Aggregate and generate report via Python
# ---------------------------------------------------------------------------
export EXPERIMENT_DIR RESULTS_DIR CONFIG_FILE

python3 << 'PYEOF'
import json, glob, os, sys, math

experiment_dir = os.environ["EXPERIMENT_DIR"]
results_dir = os.environ["RESULTS_DIR"]
config_file = os.environ["CONFIG_FILE"]

# ---------------------------------------------------------------------------
# Read experiment config (via yq output or parse yaml with basic approach)
# ---------------------------------------------------------------------------
import subprocess

def yq(expr):
    r = subprocess.run(["yq", expr, config_file], capture_output=True, text=True)
    return r.stdout.strip()

name = yq(".name")
model = yq(".agent.model")
max_turns = yq(".agent.max_turns")
base_commit = yq(".project.base_commit")
per_condition = int(yq(".runs.per_condition"))
num_conditions = int(yq(".conditions | length"))

conditions = []
for i in range(num_conditions):
    conditions.append(yq(f".conditions[{i}].name"))

# ---------------------------------------------------------------------------
# Collect metrics
# ---------------------------------------------------------------------------
all_metrics = []
for cond in conditions:
    cond_dir = os.path.join(results_dir, "runs", cond)
    if not os.path.isdir(cond_dir):
        continue
    for run_dir in sorted(glob.glob(os.path.join(cond_dir, "run-*"))):
        mf = os.path.join(run_dir, "metrics.json")
        if os.path.isfile(mf):
            with open(mf) as f:
                all_metrics.append(json.load(f))

if not all_metrics:
    print("ERROR: No metrics found", file=sys.stderr)
    sys.exit(1)

# Group by condition
by_condition = {}
for cond in conditions:
    by_condition[cond] = [m for m in all_metrics if m.get("condition") == cond]

# ---------------------------------------------------------------------------
# Statistics helpers
# ---------------------------------------------------------------------------
def avg(lst, key):
    vals = [m[key] for m in lst if isinstance(m.get(key), (int, float))]
    return sum(vals) / len(vals) if vals else 0

def median(lst, key):
    vals = sorted(m[key] for m in lst if isinstance(m.get(key), (int, float)))
    n = len(vals)
    if n == 0: return 0
    return vals[n // 2] if n % 2 else (vals[n // 2 - 1] + vals[n // 2]) / 2

def stddev(lst, key):
    vals = [m[key] for m in lst if isinstance(m.get(key), (int, float))]
    if len(vals) < 2: return 0
    m = sum(vals) / len(vals)
    return (sum((x - m) ** 2 for x in vals) / (len(vals) - 1)) ** 0.5

def ci95(lst, key):
    vals = [m[key] for m in lst if isinstance(m.get(key), (int, float))]
    n = len(vals)
    if n < 2: return (0, 0)
    m = sum(vals) / n
    s = stddev(lst, key)
    t_table = {2: 12.706, 3: 4.303, 4: 3.182, 5: 2.776, 6: 2.571,
               7: 2.447, 8: 2.365, 9: 2.306, 10: 2.262}
    t = t_table.get(n, 1.96)
    se = s / (n ** 0.5)
    return (m - t * se, m + t * se)

def cohens_d(lst_a, lst_b, key):
    av = [m[key] for m in lst_a if isinstance(m.get(key), (int, float))]
    bv = [m[key] for m in lst_b if isinstance(m.get(key), (int, float))]
    if not av or not bv: return 0
    am, bm = sum(av)/len(av), sum(bv)/len(bv)
    na, nb = len(av), len(bv)
    avar = sum((x-am)**2 for x in av)/(na-1) if na>1 else 0
    bvar = sum((x-bm)**2 for x in bv)/(nb-1) if nb>1 else 0
    pooled = math.sqrt(((na-1)*avar + (nb-1)*bvar)/(na+nb-2)) if na+nb>2 else 0
    return (bm-am)/pooled if pooled else 0

def success_rate(lst):
    if not lst: return 0
    return sum(1 for m in lst if m.get("test_exit_code") == 0 and m.get("tests_failed", 1) == 0) / len(lst)

def fmt_ms(ms):
    secs = ms / 1000
    mins = int(secs // 60)
    rem = secs % 60
    return f"{mins}m {rem:.0f}s" if mins > 0 else f"{secs:.1f}s"

def fmt_tokens(t):
    return f"{t/1000:.1f}K" if t >= 1000 else str(int(t))

def fmt_cost(usd):
    if usd >= 1.0:
        return f"${usd:.2f}"
    return f"${usd:.4f}"

# Pricing per million tokens (source: platform.claude.com/docs/en/about-claude/pricing)
PRICING = {
    "claude-sonnet-4-6":      {"input": 3.0,  "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-sonnet-4-5":      {"input": 3.0,  "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-sonnet-4":        {"input": 3.0,  "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-opus-4-6":        {"input": 5.0,  "output": 25.0, "cache_read": 0.50, "cache_write": 6.25},
    "claude-opus-4-5":        {"input": 5.0,  "output": 25.0, "cache_read": 0.50, "cache_write": 6.25},
    "claude-haiku-4-5":       {"input": 1.0,  "output": 5.0,  "cache_read": 0.10, "cache_write": 1.25},
}

def calc_cost(m, model_name):
    """Calculate estimated cost in USD for a single run."""
    rates = PRICING.get(model_name)
    if not rates:
        return None
    return (
        m.get("input_tokens", 0) * rates["input"]
        + m.get("output_tokens", 0) * rates["output"]
        + m.get("cache_read_input_tokens", 0) * rates["cache_read"]
        + m.get("cache_creation_input_tokens", 0) * rates["cache_write"]
    ) / 1_000_000

# Compute cost for each run
for m in all_metrics:
    cost = calc_cost(m, model)
    if cost is not None:
        m["estimated_cost_usd"] = round(cost, 4)

def delta_pct(a, b):
    if a == 0: return "N/A"
    pct = ((b - a) / a) * 100
    return f"{'+' if pct > 0 else ''}{pct:.1f}%"

# ---------------------------------------------------------------------------
# Build summary.json
# ---------------------------------------------------------------------------
summary = {"conditions": {}, "all_metrics": all_metrics}
for cond in conditions:
    cl = by_condition[cond]
    lo, hi = ci95(cl, "duration_ms")
    summary["conditions"][cond] = {
        "n": len(cl),
        "duration_avg": round(avg(cl, "duration_ms"), 1),
        "duration_median": round(median(cl, "duration_ms"), 1),
        "duration_stddev": round(stddev(cl, "duration_ms"), 1),
        "duration_ci95": [round(lo, 1), round(hi, 1)],
        "tokens_avg": round(avg(cl, "total_tokens"), 1),
        "tokens_median": round(median(cl, "total_tokens"), 1),
        "input_tokens_avg": round(avg(cl, "input_tokens"), 1),
        "output_tokens_avg": round(avg(cl, "output_tokens"), 1),
        "cache_read_avg": round(avg(cl, "cache_read_input_tokens"), 1),
        "cache_create_avg": round(avg(cl, "cache_creation_input_tokens"), 1),
        "tool_calls_avg": round(avg(cl, "tool_calls"), 1),
        "cost_avg": round(avg(cl, "estimated_cost_usd"), 4) if any("estimated_cost_usd" in m for m in cl) else None,
        "cost_total": round(sum(m.get("estimated_cost_usd", 0) for m in cl), 4),
        "success_rate": round(success_rate(cl), 3),
        "typecheck_pass_rate": round(
            sum(1 for m in cl if m.get("typecheck_exit_code") == 0) / max(len(cl), 1), 3),
    }

# Pairwise comparisons (first condition as baseline)
if len(conditions) >= 2:
    baseline = conditions[0]
    summary["comparisons"] = {}
    for cond in conditions[1:]:
        d_dur = cohens_d(by_condition[baseline], by_condition[cond], "duration_ms")
        d_tok = cohens_d(by_condition[baseline], by_condition[cond], "total_tokens")
        summary["comparisons"][f"{baseline}_vs_{cond}"] = {
            "duration_cohens_d": round(d_dur, 3),
            "tokens_cohens_d": round(d_tok, 3),
        }

with open(os.path.join(results_dir, "summary.json"), "w") as f:
    json.dump(summary, f, indent=2)

# ---------------------------------------------------------------------------
# Generate report.md
# ---------------------------------------------------------------------------
lines = []
p = lines.append

p(f"# Experiment Report: {name}")
p("")
p("## Setup")
p("")
p("| Variable | Value |")
p("|---|---|")
p(f"| Model | `{model}` |")
p(f"| Max turns | {max_turns} |")
p(f"| Runs/condition | {per_condition} |")
p(f"| Base commit | `{base_commit[:12]}` |")
p(f"| Conditions | {', '.join(conditions)} |")

# Read started_at from experiment-run.json if available
run_meta_path = os.path.join(results_dir, "experiment-run.json")
if os.path.isfile(run_meta_path):
    with open(run_meta_path) as f:
        rm = json.load(f)
    p(f"| Started | {rm.get('started_at', 'N/A')} |")

p("")
p("---")
p("")
p("## Summary")
p("")

# Header row: Metric | Condition1 | Condition2 | ... | Delta
header = "| Metric |"
sep = "|---|"
for c in conditions:
    header += f" {c} |"
    sep += "---|"
if len(conditions) >= 2:
    header += " Delta |"
    sep += "---|"

p(header)
p(sep)

def row(label, key, fmt_fn=str, bold=False):
    name = f"**{label}**" if bold else label
    r = f"| {name} |"
    vals = []
    for c in conditions:
        v = avg(by_condition[c], key) if "avg" not in label.lower() else avg(by_condition[c], key)
        vals.append(v)
        r += f" {fmt_fn(v)} |"
    if len(conditions) >= 2:
        r += f" {delta_pct(vals[0], vals[1])} |"
    p(r)

row("Duration (avg)", "duration_ms", fmt_ms, bold=True)
row("Duration (median)", "duration_ms",
    lambda v: fmt_ms(median(by_condition[conditions[0]], "duration_ms")) if v == avg(by_condition[conditions[0]], "duration_ms") else fmt_ms(v))

# Duration CI
r = "| Duration (95% CI) |"
for c in conditions:
    lo, hi = ci95(by_condition[c], "duration_ms")
    r += f" {fmt_ms(lo)}\u2013{fmt_ms(hi)} |"
if len(conditions) >= 2:
    r += " - |"
p(r)

row("Total tokens (avg)", "total_tokens", fmt_tokens, bold=True)
row("Input tokens (avg)", "input_tokens", fmt_tokens)
row("Output tokens (avg)", "output_tokens", fmt_tokens)
row("Cache read (avg)", "cache_read_input_tokens", fmt_tokens)
row("Cache create (avg)", "cache_creation_input_tokens", fmt_tokens)
row("Tool calls (avg)", "tool_calls", lambda v: f"{v:.1f}", bold=True)

# Cost row
if any("estimated_cost_usd" in m for m in all_metrics):
    row("**Est. cost/run (avg)**", "estimated_cost_usd", fmt_cost, bold=False)

    # Total cost per condition
    r = "| Est. cost total |"
    for c in conditions:
        total = sum(m.get("estimated_cost_usd", 0) for m in by_condition[c])
        r += f" {fmt_cost(total)} |"
    if len(conditions) >= 2:
        totals = [sum(m.get("estimated_cost_usd", 0) for m in by_condition[c]) for c in conditions]
        r += f" {delta_pct(totals[0], totals[1])} |"
    p(r)

    # Experiment total
    grand_total = sum(m.get("estimated_cost_usd", 0) for m in all_metrics)
    p(f"| **Est. experiment total** | | | **{fmt_cost(grand_total)}** |")

# Success rates
r = "| **Test success** |"
for c in conditions:
    r += f" {success_rate(by_condition[c])*100:.0f}% |"
if len(conditions) >= 2:
    r += " - |"
p(r)

# Effect sizes
if len(conditions) >= 2:
    p("")
    p("### Effect Sizes")
    p("")
    base = conditions[0]
    for c in conditions[1:]:
        d_dur = cohens_d(by_condition[base], by_condition[c], "duration_ms")
        d_tok = cohens_d(by_condition[base], by_condition[c], "total_tokens")
        eff = lambda d: "large" if abs(d)>=0.8 else "medium" if abs(d)>=0.5 else "small" if abs(d)>=0.2 else "negligible"
        p(f"- Duration: Cohen's d = {d_dur:.3f} ({eff(d_dur)})")
        p(f"- Tokens: Cohen's d = {d_tok:.3f} ({eff(d_tok)})")

p("")
p("---")
p("")
p("## Per-Run Details")

for cond in conditions:
    cl = by_condition[cond]
    p("")
    p(f"### {cond}")
    p("")
    has_cost = any("estimated_cost_usd" in m for m in cl)
    if has_cost:
        p("| Run | Duration | Tokens | Cost | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |")
        p("|---|---|---|---|---|---|---|---|---|")
    else:
        p("| Run | Duration | Tokens | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |")
        p("|---|---|---|---|---|---|---|---|")
    for m in cl:
        tc = "PASS" if m.get("typecheck_exit_code") == 0 else "FAIL"
        cm = "Yes" if m.get("has_commit") else "No"
        cost_col = f" {fmt_cost(m['estimated_cost_usd'])} |" if has_cost else ""
        p(f"| {m.get('run', '?')} | {fmt_ms(m.get('duration_ms', 0))} | {fmt_tokens(m.get('total_tokens', 0))} |{cost_col} {m.get('tool_calls', 0)} | {m.get('tests_passed', 0)} | {m.get('tests_failed', 0)} | {tc} | {cm} |")

# Commit messages
p("")
p("---")
p("")
p("## Commit Messages")
p("")
for m in all_metrics:
    if m.get("has_commit") and m.get("commit_message"):
        p(f"- **{m['condition']} run {m.get('run', '?')}:** `{m['commit_message']}`")

p("")
p("---")
p("")
p("## Reproducibility")
p("")
p("All artifacts are in the results directory:")
p("")
p("- `experiment.yaml.reference` — experiment config snapshot")
p("- `task-prompt.reference` — exact prompt used")
p("- `runs/<condition>/run-<N>/metrics.json` — per-run data")
p("- `runs/<condition>/run-<N>/session.json` — full agent logs")
p("- `runs/<condition>/run-<N>/changes.diff` — git diffs")
p("- `summary.json` — aggregated statistics")

report_text = "\n".join(lines)
with open(os.path.join(results_dir, "report.md"), "w") as f:
    f.write(report_text)

print(report_text)
PYEOF

echo ""
echo "Report: $REPORT"
echo "Summary: $SUMMARY"
