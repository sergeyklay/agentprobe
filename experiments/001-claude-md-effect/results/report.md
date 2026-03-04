# Experiment Report: CLAUDE.md Effect on Agent Performance

## Setup

| Variable       | Value                             |
| -------------- | --------------------------------- |
| Model          | claude-haiku-4-5                  |
| Max turns      | 50                                |
| Runs/condition | 5                                 |
| Base commit    | a09921e2de2e                      |
| Conditions     | without-claude-md, with-claude-md |
| Started        | 2026-03-04T21:20:31Z              |

---

## Summary

| Metric                | without-claude-md | with-claude-md | Delta  |
| --------------------- | ----------------- | -------------- | ------ |
| Duration (avg)        | 5m 1s             | 4m 15s         | -15.1% |
| Duration (median)     | 4m 56s            | 4m 7s          | -16.6% |
| Duration (95% CI)     | 3m 51s–6m 10s     | 3m 11s–5m 19s  | -      |
| Total tokens (avg)    | 15756.3K          | 13677.3K       | -13.2% |
| Input tokens (avg)    | 1.3K              | 1.1K           | -13.0% |
| Output tokens (avg)   | 23.4K             | 22.6K          | -3.3%  |
| Cache read (avg)      | 15390.0K          | 13286.7K       | -13.7% |
| Cache create (avg)    | 341.6K            | 366.9K         | +7.4%  |
| Tool calls (avg)      | 46.4              | 39.4           | -15.1% |
| Est. cost/run (avg)   | $2.08             | $1.90          | -8.8%  |
| Est. cost total       | $10.42            | $9.51          | -8.8%  |
| Est. experiment total |                   |                | $19.93 |
| Test success          | 60%               | 100%           | -      |
| pass@1                | 60.0%             | 100.0%         | -      |
| pass@3                | 100.0%            | 100.0%         | -      |
| pass@5                | 100.0%            | 100.0%         | -      |

### Effect Sizes

- Duration: Cohen's d = -0.846 (large)
- Tokens: Cohen's d = -0.995 (large)

---

## Per-Run Details

### without-claude-md

| Run | Duration | Tokens   | Cost  | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |
| --- | -------- | -------- | ----- | ---------- | ---------- | ---------- | --------- | --------- |
| 1   | 5m 41s   | 18538.6K | $2.62 | 51         | 154        | 0          | PASS      | Yes       |
| 2   | 4m 56s   | 15630.9K | $2.13 | 50         | 101        | 52         | PASS      | No        |
| 3   | 3m 44s   | 14548.6K | $1.86 | 44         | 29681      | 0          | PASS      | Yes       |
| 4   | 4m 36s   | 12477.0K | $1.62 | 36         | 29677      | 0          | PASS      | Yes       |
| 5   | 6m 6s    | 17586.3K | $2.20 | 51         | 152        | 2          | PASS      | No        |

### with-claude-md

| Run | Duration | Tokens   | Cost  | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |
| --- | -------- | -------- | ----- | ---------- | ---------- | ---------- | --------- | --------- |
| 1   | 4m 7s    | 14957.3K | $2.04 | 47         | 29681      | 0          | PASS      | Yes       |
| 2   | 4m 47s   | 15505.6K | $2.24 | 40         | 154        | 0          | PASS      | Yes       |
| 3   | 3m 49s   | 14148.8K | $1.77 | 46         | 29680      | 0          | PASS      | Yes       |
| 4   | 3m 10s   | 11791.9K | $1.76 | 32         | 29681      | 0          | PASS      | Yes       |
| 5   | 5m 23s   | 11982.8K | $1.70 | 32         | 153        | 0          | PASS      | Yes       |

---

## Commit Messages

- **without-claude-md run 1:** `fix(no-unnecessary-type-assertion): preserve assertions on narrowed function call results`
- **without-claude-md run 3:** `test(eslint-plugin): [no-unnecessary-type-assertion] add narrowing and closure edge case tests`
- **without-claude-md run 4:** `test(no-unnecessary-type-assertion): add test cases for type narrowing scenarios`
- **with-claude-md run 1:** `test(eslint-plugin): [no-unnecessary-type-assertion] add type narrowing tests`
- **with-claude-md run 2:** `fix(no-unnecessary-type-assertion): avoid false positives with type narrowing`
- **with-claude-md run 3:** `test(eslint-plugin): add test cases for no-unnecessary-type-assertion type narrowing`
- **with-claude-md run 4:** `test(eslint-plugin): [no-unnecessary-type-assertion] add comprehensive type narrowing test cases`
- **with-claude-md run 5:** `fix(eslint-plugin): prevent false positives in no-unnecessary-type-assertion for narrowed types`

---

## Reproducibility

All artifacts are in the results directory:

- `experiment.yaml.reference` — experiment config snapshot
- `task-prompt.reference` — exact prompt used
- `runs/<condition>/run-<N>/metrics.json` — per-run data
- `runs/<condition>/run-<N>/session.json` — full agent logs
- `runs/<condition>/run-<N>/changes.diff` — git diffs
- `summary.json` — aggregated statistics
