---
status: todo
complexity: 2-3 hours
depends_on:
  - 002-structured-test-reporters
  - 003-baseline-test-recording
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Failure classification (B1/B2/B3 categories)

## What

Classify each failed run into diagnostic categories based on SWE-rebench V2 taxonomy:

- **B1 (Test Suite Coupling):** Agent correctly fixed the target issue but broke unrelated tests (regressions). The fix itself is valid — side effects are the problem.
- **B2 (Implicit Naming):** Agent's solution is functionally correct but tests expect specific names, signatures, or implementation details not mentioned in the task prompt.
- **B3 (External Dependencies):** Failure caused by inaccessible external resources (URLs, APIs, services) referenced in the task.

## Why

AgentProbe currently records `tests_passed=245, tests_failed=3` — this doesn't explain WHY.

If 2/5 runs in with-claude-md fail and 3/5 without fail — the success rate difference looks like CLAUDE.md helps. But if ALL failures are B1 (regressions), then CLAUDE.md doesn't help fix the bug better — it helps avoid breaking other things. That's a fundamentally different conclusion about what context files do.

Failure classification turns "X% success rate" into actionable insights about agent behavior patterns.

## Where

- `runner.sh` or new `framework/lib/failure-analysis.sh` — classification logic
- `metrics.json` — add `failure_category` field (null for successful runs, "B1"/"B2"/"B3"/"unknown" for failures)
- `report_generator.py` — add failure breakdown to report

## Classification logic

Given baseline tests (task 003) and structured post-agent tests (task 002):

```
baseline_failing = set of tests that fail before agent
post_failing = set of tests that fail after agent

if post_failing is empty:
    success (no classification needed)

if (baseline_failing - post_failing) is non-empty AND (post_failing - baseline_failing) is non-empty:
    B1 — agent fixed some tests but broke others

if post_failing == baseline_failing:
    agent didn't fix anything (separate from B1/B2/B3 — "no effect")

# B2 and B3 require deeper analysis (test error messages, network access patterns)
# Start with B1 detection which is purely mechanical
```

## Acceptance

- Each failed run gets a `failure_category` in metrics.json
- B1 is detected automatically from test set comparison
- Report includes failure category breakdown per condition
- B2/B3 can be "unknown" initially — manual classification acceptable as V1
