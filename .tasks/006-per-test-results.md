---
status: todo
complexity: 2-3 hours
depends_on:
  - 002-structured-test-reporters
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Per-test result tracking

## What

Save the full per-test breakdown (name, status, duration, error message) from structured test reporters into `test-results.json` alongside `metrics.json` in each run directory.

## Why

Current metrics are two numbers: `tests_passed=245, tests_failed=0`. This hides:

1. **Which tests are affected?** If with-claude-md consistently passes test X that without-claude-md fails — that's a targeted signal about what CLAUDE.md helps with.

2. **Did the agent add new tests?** If the total test count differs between conditions, the agent in one condition is generating more edge-case coverage (observed in v0 archive results).

3. **Cross-run stability.** If test Y fails in 2 of 5 runs of condition A but 0 of 5 in condition B — that's a flaky-vs-stable signal invisible in aggregate numbers.

4. **Error message analysis.** Failed test error messages reveal whether the agent misunderstood the problem (wrong approach) vs. made a small mistake (off-by-one, wrong variable name).

SWE-rebench V2 stores full test lists for each of their 32K tasks, enabling the B1/B2/B3 classification (task 004) and curriculum analysis.

## Where

- `runner.sh` — save structured test output to `test-results.json`
- Results directory: `runs/<condition>/run-<N>/test-results.json`
- `report_generator.py` — optionally render per-test comparison table (for small test counts)

## Schema

```json
{
  "test_runner": "vitest",
  "total": 247,
  "passed": 245,
  "failed": 2,
  "skipped": 0,
  "duration_ms": 12340,
  "tests": [
    {
      "name": "no-unnecessary-type-assertion > valid > should allow assertion on generic constraint",
      "status": "passed",
      "duration_ms": 45
    },
    {
      "name": "no-unnecessary-type-assertion > invalid > should flag redundant assertion after narrowing",
      "status": "failed",
      "duration_ms": 12,
      "error": "Expected 1 error but got 0"
    }
  ]
}
```

## Acceptance

- Each run directory contains `test-results.json` with full per-test breakdown
- Test count (sum of passed+failed+skipped) is verifiable
- Error messages for failed tests are captured
- File size is reasonable (< 1MB even for large test suites)
