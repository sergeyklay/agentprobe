---
status: todo
complexity: 2 hours
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Full test suite as secondary regression metric

## What

Add an optional `verification.regression_test_command` to experiment.yaml that runs a broader test suite (beyond the task-specific tests) to detect side effects and regressions.

Record results as secondary metrics — NOT affecting `success_rate`, but tracked separately in the report.

## Why

Experiment 001 runs only the specific rule test file (`no-unnecessary-type-assertion.test.ts`). This answers "did the agent fix the bug?" but NOT "did the agent break anything else?".

If the agent modifies a shared utility in `type-utils/`, it could break other rules. The CLAUDE.md artifact explicitly mentions monorepo dependencies ("eslint-plugin depends on parser, type-utils, typescript-estree") — the hypothesis is that this knowledge helps the agent avoid regressions. But without running broader tests, this benefit is invisible.

SWE-rebench V2 runs the full project test suite for every task — not just task-specific tests — specifically to detect side effects. They found this catches real issues that targeted tests miss.

## Where

- `experiment.yaml` — add `verification.regression_test_command` (optional)
- `runner.sh` — add regression test step after primary verification
- `metrics.json` — add `regression_tests_passed`, `regression_tests_failed`, `regression_test_exit_code`
- `report_generator.py` — add regression metrics to summary table

## Design notes

For experiment 001 (typescript-eslint), a reasonable regression command:

```bash
npx vitest run packages/eslint-plugin/tests/rules/ --reporter=json
```

This runs ALL rule tests (not just the one the agent changed). Takes ~2-3 minutes.

The regression command should have its own timeout (separate from `verification.timeout`), since full suites take longer.

## Acceptance

- `experiment.yaml` supports optional `regression_test_command`
- Regression test results are recorded in metrics.json as secondary metrics
- success_rate is NOT affected by regression test results
- Report shows regression metrics separately
- Experiments without regression_test_command still work (backward compatible)
