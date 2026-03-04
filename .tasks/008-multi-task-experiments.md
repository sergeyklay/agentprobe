---
status: todo
complexity: 1 day
depends_on:
  - 007-task-metadata
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Multi-task experiments for generalizability

## What

Extend experiment.yaml and orchestrator.sh to support multiple tasks within one experiment. Each task is tested under all conditions, producing cross-task effect sizes.

```yaml
tasks:
  - name: "no-unnecessary-type-assertion-bug"
    prompt_file: "tasks/task-1-prompt.txt"
    base_commit: "a09921e..."
    verification:
      test_command: "npx vitest run packages/eslint-plugin/tests/rules/no-unnecessary-type-assertion.test.ts"
  - name: "consistent-type-exports-edge-case"
    prompt_file: "tasks/task-2-prompt.txt"
    base_commit: "b12345f..."
    verification:
      test_command: "npx vitest run packages/eslint-plugin/tests/rules/consistent-type-exports.test.ts"
```

Run schedule becomes: `task1-condA-run1, task1-condB-run1, task2-condA-run1, task2-condB-run1, ...`

## Why

This is the single most impactful change for the credibility of AgentProbe's findings.

SWE-rebench V2 shows pass rates vary wildly across tasks (2.8%-36.1% in their diagnostic study). If CLAUDE.md "helps" on one specific task, that could be an artifact — the CLAUDE.md for experiment 001 contains `getConstrainedTypeAtLocation()` which is a direct hint to the solution. A skeptic would say "of course it helps — you gave it the answer."

If CLAUDE.md helps across 5 different tasks from the same repo — none of which have direct hints — that's a robust finding.

Practical approach: mine typescript-eslint for fail-to-pass PRs (the SWE-rebench V2 methodology). Pick 5 diverse bugs. Same CLAUDE.md, same conditions, 5 tasks x 2 conditions x 5 runs = 50 agent runs.

## Where

- `experiment.yaml` — support `tasks` array (or keep single `task` for backward compat)
- `orchestrator.sh` — nested loop: tasks x conditions x runs
- `runner.sh` — accept task-specific base_commit and verification
- `report_generator.py` — per-task breakdown + cross-task summary with aggregate effect sizes
- Results directory: `runs/<task>/<condition>/run-<N>/`

## Design considerations

1. **Backward compatibility.** Single-task `task:` key should still work. `tasks:` is the multi-task variant.

2. **Scheduling.** Interleaving should happen across conditions within each task, not across tasks. Task A runs to completion before task B starts — different base commits require different worktree states.

3. **Cost.** 5 tasks x 2 conditions x 5 runs x $4-6/run = $200-$300. Significant but within research budget for a publishable result.

4. **Task discovery.** Could leverage SWE-rebench V2's methodology: find merged PRs with test changes, extract fail-to-pass tests, generate task prompts. This is a natural extension.

## Acceptance

- experiment.yaml supports `tasks` array with per-task configs
- Orchestrator runs all tasks under all conditions
- Report includes per-task breakdown AND cross-task aggregate
- Cross-task Cohen's d reported for key metrics
- Single-task experiments still work unchanged
