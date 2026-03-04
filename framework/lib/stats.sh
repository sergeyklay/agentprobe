#!/usr/bin/env bash
# stats.sh - Statistical calculations for experiment metrics
#
# Provides: calc_stats, calc_field_stats, compare_conditions
# Requires: python3

# Compute descriptive stats for a JSON array of numbers on stdin.
# Output: JSON with mean, median, stddev, ci95_low, ci95_high, min, max, n
# Usage: echo '[1,2,3,4,5]' | calc_stats
calc_stats() {
  local input
  input=$(cat)
  STATS_INPUT="$input" python3 -c '
import json, sys, math, os

data = json.loads(os.environ["STATS_INPUT"])
vals = [x for x in data if isinstance(x, (int, float))]
n = len(vals)

if n == 0:
    json.dump({"mean": 0, "median": 0, "stddev": 0, "ci95_low": 0, "ci95_high": 0, "min": 0, "max": 0, "n": 0}, sys.stdout)
    sys.exit(0)

mean = sum(vals) / n
sv = sorted(vals)
median = sv[n // 2] if n % 2 else (sv[n // 2 - 1] + sv[n // 2]) / 2
stddev = (sum((x - mean) ** 2 for x in vals) / (n - 1)) ** 0.5 if n >= 2 else 0

t_table = {2: 12.706, 3: 4.303, 4: 3.182, 5: 2.776, 6: 2.571,
           7: 2.447, 8: 2.365, 9: 2.306, 10: 2.262}
t_val = t_table.get(n, 1.96)
se = stddev / (n ** 0.5) if n > 0 else 0

json.dump({
    "mean": round(mean, 2),
    "median": round(median, 2),
    "stddev": round(stddev, 2),
    "ci95_low": round(mean - t_val * se, 2),
    "ci95_high": round(mean + t_val * se, 2),
    "min": round(min(vals), 2),
    "max": round(max(vals), 2),
    "n": n
}, sys.stdout)
'
}

# Extract a field from a JSON array of objects and compute stats.
# Usage: cat metrics_array.json | calc_field_stats "duration_ms"
calc_field_stats() {
  local field="$1"
  jq "[.[] | .${field} // 0]" | calc_stats
}

# Compare two conditions and compute effect size (Cohen's d).
# Reads two JSON arrays of metric objects from files.
# Usage: compare_conditions a_metrics.json b_metrics.json "duration_ms"
compare_conditions() {
  local file_a="$1"
  local file_b="$2"
  local field="$3"

  python3 -c "
import json, math, sys

with open('$file_a') as f: a = json.load(f)
with open('$file_b') as f: b = json.load(f)

av = [m['$field'] for m in a if isinstance(m.get('$field'), (int, float))]
bv = [m['$field'] for m in b if isinstance(m.get('$field'), (int, float))]

am = sum(av)/len(av) if av else 0
bm = sum(bv)/len(bv) if bv else 0
na, nb = len(av), len(bv)

avar = sum((x-am)**2 for x in av)/(na-1) if na>1 else 0
bvar = sum((x-bm)**2 for x in bv)/(nb-1) if nb>1 else 0

pooled = math.sqrt(((na-1)*avar + (nb-1)*bvar)/(na+nb-2)) if na+nb>2 else 0
d = (bm-am)/pooled if pooled>0 else 0
pct = ((bm-am)/am*100) if am else 0

size = 'large' if abs(d)>=0.8 else 'medium' if abs(d)>=0.5 else 'small' if abs(d)>=0.2 else 'negligible'
json.dump({'a_mean': round(am,2), 'b_mean': round(bm,2), 'delta_pct': round(pct,1), 'cohens_d': round(d,3), 'effect_size': size}, sys.stdout)
"
}
