---
status: done
complexity: 15 min
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# pass@k metric in report

## What

Add pass@k metric to `report_generator.py` alongside existing success_rate.

Formula: `pass@k = 1 - C(n-c, k) / C(n, k)` where n = total runs, c = successful runs.

Report pass@1, pass@3, pass@5 (or whatever the per_condition count is).

## Why

success_rate answers "how often does the agent succeed?" — useful for reliability.
pass@k answers "if I give the agent k attempts, will I get at least one working solution?" — useful for practical usage.

These are complementary metrics computed from the same data. Zero collection cost — purely a report-generator change.

SWE-rebench V2 reports all results as pass@k. This is the standard in the field (HumanEval, SWE-bench, MBPP all use pass@k).

## Where

- `framework/report_generator.py` — add pass_at_k() function, add rows to summary table
- `framework/report-generator.sh` — no changes needed (thin wrapper)

## Acceptance

- `summary.json` contains pass@k values per condition
- `report.md` shows pass@k in the summary table
- Matches manual calculation from existing test data
