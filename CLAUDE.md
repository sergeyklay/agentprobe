# CLAUDE.md

## Project

AgentProbe — a multi-hypothesis benchmark framework for AI coding agents.
Shell-based (bash + jq + yq + python3). No build step.

## Commands

- Run experiment: `bash framework/orchestrator.sh experiments/<name>/`
- Dry-run (preview schedule): `bash framework/orchestrator.sh experiments/<name>/ --dry-run`
- Generate report only: `bash framework/report-generator.sh experiments/<name>/`
- Extract metrics from log: `bash framework/metrics-collector.sh <log_file>`

## Structure

- `framework/` — reusable engine (orchestrator, runner, libs)
- `experiments/` — one directory per hypothesis, each with `experiment.yaml`
- `research/` — background research documents
- `archive/` — preserved v0 results

## Adding experiments

1. Create `experiments/<NNN>-<name>/` with `experiment.yaml`, `hypothesis.md`, `task-prompt.txt`
2. Add `conditions/<name>/setup.sh` for each condition (receives worktree path as $1)
3. No framework changes needed

## Architecture gotchas

- Config is YAML parsed by `yq` (mikefarah v4), not JSON
- Each agent run uses `git worktree` for isolation — main repo is never touched
- Interleaving (A-B-A-B) controlled by `runs.interleave` in experiment.yaml
- `metrics-collector.sh` tracks cache tokens separately from input tokens
- `framework/lib/stats.sh` uses python3 for statistics (CI, Cohen's d)

## Boundaries

### Always

- All code/comments/docs in English
- Run shellcheck on modified .sh files
- Use `set -euo pipefail` in all scripts
- Source lib files with `source "$FRAMEWORK_DIR/lib/<name>.sh"`

### Never

- Never run `pnpm install` or `npm install`
- Never modify archived results in `archive/`
- Never hardcode condition names in framework scripts — read from experiment.yaml
