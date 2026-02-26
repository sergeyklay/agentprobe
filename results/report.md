# Experiment Report: CLAUDE.md Effect on Agent Performance

## Objective

Test whether a well-crafted `CLAUDE.md` context file improves Claude Code agent
performance when working on a real task in the `typescript-eslint` monorepo.
This experiment addresses the claim from the ETH Zurich study (Gloaguen et al.,
arXiv:2602.11988) that context files may hurt agent performance.

---

## Experimental Setup

| Variable           | Value                                   |
| ------------------ | --------------------------------------- |
| Agent              | Claude Code (headless, `-p` flag)       |
| Model              | `claude-sonnet-4-6`                     |
| Max turns          | 50                                      |
| Runs per condition | 2                                       |
| Base commit        | `a09921e2de2e`                          |
| Project            | typescript-eslint/typescript-eslint     |
| Condition A        | No CLAUDE.md                            |
| Condition B        | With CLAUDE.md (~45 lines, handcrafted) |
| Started            | 2026-02-26T13:37:24Z                    |

**Task prompt:** Identical for both conditions (see `task-prompt.reference`).

**CLAUDE.md content:** See `CLAUDE.md.reference` in results directory.

---

## Results

### Summary Table

| Metric                 | Without CLAUDE.md | With CLAUDE.md | Delta   |
| ---------------------- | ----------------- | -------------- | ------- |
| **Duration (avg)**     | 9m 52s            | 25m 14s        | +155.5% |
| Duration (median)      | 9m 52s            | 25m 14s        | +155.5% |
| Duration (stddev)      | 55.4s             | 3m 23s         | -       |
| **Total tokens (avg)** | 3859.0K           | 6081.1K        | +57.6%  |
| Tokens (median)        | 3859.0K           | 6081.1K        | +57.6%  |
| **Tool calls (avg)**   | 22.5              | 25.0           | +11.1%  |
| **Test success rate**  | 100%              | 100%           | 0.0%    |
| Typecheck pass rate    | 100%              | 100%           | -       |
| Commit rate            | 100%              | 100%           | -       |

### Per-Run Details

#### Condition A: Without CLAUDE.md

| Run | Duration | Tokens  | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |
| --- | -------- | ------- | ---------- | ---------- | ---------- | --------- | --------- |
| 1   | 9m 13s   | 3454.5K | 20         | 29679      | 0          | PASS      | Yes       |
| 2   | 10m 32s  | 4263.6K | 25         | 29680      | 0          | PASS      | Yes       |

#### Condition B: With CLAUDE.md

| Run | Duration | Tokens  | Tool Calls | Tests Pass | Tests Fail | Typecheck | Committed |
| --- | -------- | ------- | ---------- | ---------- | ---------- | --------- | --------- |
| 1   | 27m 37s  | 7108.8K | 28         | 29678      | 0          | PASS      | Yes       |
| 2   | 22m 50s  | 5053.4K | 22         | 29679      | 0          | PASS      | Yes       |

---

## Analysis

### Speed: CLAUDE.md was 155% slower

Average duration without CLAUDE.md: 9m 52s (stddev: 55.4s)
Average duration with CLAUDE.md: 25m 14s (stddev: 3m 23s)

### Tokens: CLAUDE.md used 58% more tokens

Average tokens without CLAUDE.md: 3859.0K
Average tokens with CLAUDE.md: 6081.1K

### Task success

Without CLAUDE.md: 100% of runs had all tests passing
With CLAUDE.md: 100% of runs had all tests passing

### Commit messages

- **with run 1:** `test(eslint-plugin): [no-unnecessary-type-assertion] add edge case tests for type narrowing with non-null assertions`
- **with run 2:** `test(eslint-plugin): add test cases for no-unnecessary-type-assertion with type guard narrowing`
- **without run 1:** `test(eslint-plugin): add test coverage for type-guard narrowing with non-null assertions`
- **without run 2:** `test(no-unnecessary-type-assertion): add test cases for narrowing and non-null assertions`

---

## Conclusions

| Hypothesis                                     | Result                                |
| ---------------------------------------------- | ------------------------------------- |
| CLAUDE.md reduces time to solution             | **Refuted** (slower)                  |
| CLAUDE.md reduces token usage                  | **Refuted** (more tokens)             |
| CLAUDE.md improves solution quality            | **Inconclusive** (equal success rate) |
| CLAUDE.md hurts performance (ETH Zurich claim) | **Not observed**                      |

---

## Reproducibility

All data needed to reproduce this experiment is in the results directory:

- `experiment-config.json` - experiment parameters
- `CLAUDE.md.reference` - exact CLAUDE.md used
- `task-prompt.reference` - exact prompt given to both agents
- `*_metrics.json` - per-run quantitative data
- `logs/` - full Claude Code stream-json session logs
- `diffs/` - git diffs for each run
- `aggregated.json` - combined metrics for analysis

## Appendix: Branch Information

- `experiment/with-claude-md/run-1` - 638042bb7262 - PASS
- `experiment/with-claude-md/run-2` - 27456a379d63 - PASS
- `experiment/without-claude-md/run-1` - 6d8c1f10cfb7 - PASS
- `experiment/without-claude-md/run-2` - f6dd0476c471 - PASS
