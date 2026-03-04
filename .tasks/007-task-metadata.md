---
status: todo
complexity: 2-3 hours
origin: "SWE-rebench V2 (arxiv:2602.23866)"
---

# Task metadata: type, complexity, category

## What

Add structured metadata to each task/experiment for cross-experiment comparison:

```yaml
task:
  prompt_file: "task-prompt.txt"
  metadata:
    type: "bug-fix" # bug-fix | feature | refactoring | test | docs
    difficulty: "medium" # trivial | easy | medium | hard | expert
    scope_files: 2 # expected files to change (from known solution)
    scope_lines: 42 # expected lines to change
    domain: "static-analysis" # free-form domain tag
    requires_context: true # does the task need non-discoverable info?
```

## Why

AgentProbe currently has one experiment with one task. But `hipotesis.md` lists 3 hypotheses, and each needs multiple tasks to be credible.

When comparing CLAUDE.md effect across 5 different tasks, you need to slice results by:

- "CLAUDE.md helps more on hard tasks" — requires difficulty metadata
- "CLAUDE.md helps more on bug-fixes than features" — requires type metadata
- "CLAUDE.md reduces files changed only on multi-file tasks" — requires scope metadata

SWE-rebench V2 tags all 32K tasks by PR category (12 types), files/lines changed, and language. Their diagnostic study (Table 6) shows pass rates vary 2.8%-36.1% by language alone — without metadata you can't tell if that's language difficulty or model weakness.

This is preparation for task 008 (multi-task experiments). Low effort now, high ROI later.

## Where

- `experiment.yaml` — add optional `task.metadata` section
- `metrics.json` — copy task metadata into each run's metrics (for aggregation)
- `report_generator.py` — display task metadata in report header
- `framework/lib/validation.sh` — validate metadata fields if present

## Auto-derivable metadata

Some metadata can be computed automatically from the known solution (if base_commit has the fix):

- `scope_files`: `git diff --stat base_commit..fix_commit | wc -l`
- `scope_lines`: `git diff --numstat base_commit..fix_commit | sum`
- `type`: heuristic from commit message ("fix" -> bug-fix, "feat" -> feature)

## Acceptance

- experiment.yaml supports optional task.metadata section
- Metadata propagates to metrics.json and report.md
- Experiments without metadata still work (backward compatible)
- At least type and difficulty are documented with clear value sets
