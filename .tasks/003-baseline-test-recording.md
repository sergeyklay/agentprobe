---
status: todo
complexity: 1 hour
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Baseline test recording (fail-to-pass validation)

## What

Run the verification test command BEFORE the agent starts (on the clean worktree at base_commit) to record baseline test results. After the agent finishes, compare baseline vs post-agent results to identify fail-to-pass transitions.

## Why

Without a baseline, AgentProbe has a blind spot. Current scheme cannot distinguish:

- Agent fixed the target bug (fail -> pass) = **real success**
- Tests were already passing (pass -> pass) = **false positive**
- Agent wrote new passing tests but didn't fix anything = **ambiguous**

The dual-pass validation is the CORE methodological contribution of SWE-rebench V2. Every task in their 32K dataset is validated this way. It's the gold standard for SWE benchmarks.

In experiment 001, the test_command dynamically finds the changed rule file via `git diff`. If the agent changes nothing or changes the wrong file, the command may silently succeed or fail in uninformative ways. A baseline recording eliminates this ambiguity.

## Where

- `runner.sh` — add pre-agent verification step (between worktree setup and agent invocation)
- `metrics.json` — add fields: `baseline_tests_passed`, `baseline_tests_failed`, `tests_fixed` (fail->pass count), `tests_regressed` (pass->fail count)
- `report_generator.py` — display fail-to-pass metrics in report

## Design notes

The baseline test command should be the SAME test_command but run on the unmodified worktree. Problem: current test_command uses `git diff` to find changed files, which won't work pre-agent (no changes yet).

Options:

1. Add separate `verification.baseline_test_command` in experiment.yaml
2. Run the full test file specified in the task (not dynamically discovered)
3. Record which test file the agent ultimately changes, then retroactively run baseline

Option 1 is cleanest — keeps experiment.yaml as the single source of truth.

## Acceptance

- `metrics.json` includes `baseline_tests_passed`, `baseline_tests_failed`
- `metrics.json` includes `tests_fixed` (fail->pass) and `tests_regressed` (pass->fail)
- Baseline results are recorded before agent runs (verified by timestamps)
- Report shows fail-to-pass analysis
