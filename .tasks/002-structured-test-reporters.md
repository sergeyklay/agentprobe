---
status: todo
complexity: 30 min
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Structured test reporters instead of regex parsing

## What

Replace regex-based test output parsing with structured reporters (JSON).

Currently `runner.sh` parses vitest output via:

```bash
grep -oP '\d+(?= passed)'
grep -oP '\d+(?= failed)'
```

Switch to `--reporter=json` for vitest and `--json` for jest. Parse the JSON output instead of grepping stdout.

## Why

Regex parsing is fragile:

- vitest format changes between versions break extraction
- stdout contamination from the test suite itself can match patterns
- No per-test granularity — only aggregate counts

JSON reporters provide:

- Stable, versioned schema
- Per-test results: name, status, duration, error message
- Foundation for tasks 004 (failure classification) and 006 (per-test tracking)

SWE-rebench V2 explicitly recommends structured reports (JUnit XML) over stdout parsing, noting it significantly improves stability across language ecosystems.

## Where

- `experiment.yaml` — add optional `verification.test_reporter: json` field.
- `runner.sh` — rework test result parsing to handle JSON output
- `.claude/skills/creating-experiment/assets/experiment.yaml.tmpl` — add test_reporter field with comment about supported values: json|raw. Default to "raw" for backward compatibility.
- `framework/lib/test-parsers/` — consider extracting vitest-json and jest-json parsers. for raw output, keep existing regex parsers.
- consider updating other related files to reflect structured test reporters support

## Acceptance

- vitest JSON output is captured and parsed correctly
- `tests_passed`, `tests_failed` in metrics.json match previous regex results
- Per-test results are available (even if not yet stored — see task 006)
- Existing experiments still work (backward compatible)
