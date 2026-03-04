# CLAUDE.md

## Commands

- Run experiment: `bash framework/orchestrator.sh experiments/<name>/`
- Dry-run: `bash framework/orchestrator.sh experiments/<name>/ --dry-run`
- Clean up stuck worktrees: `source framework/lib/git-isolation.sh && cleanup_all_worktrees ~/work/<project>`

## Architecture gotchas

- Config is YAML parsed by `yq` (mikefarah v4), NOT `yq` from Python (`pip install yq`) — they have incompatible syntax
- `create_worktree()` must send all git output to stderr — stdout is captured as the worktree path. Any stdout contamination breaks `cd "$worktree_dir"`
- `set -e` + bash arithmetic `((var++))` returns exit code 1 when var is 0 — use `var=$((var + 1))` instead
- `experiment.yaml` multiline `test_command` is passed through `eval` — it must be valid bash, not just a single command
- `$AGENTPROBE_BASE_COMMIT` is exported by runner.sh before eval of test_command — use it instead of `HEAD~1` (agent may not have committed)
- Cache tokens (`cache_read_input_tokens`, `cache_creation_input_tokens`) are tracked separately from `input_tokens` — do not lump them together
- Verification commands (test, typecheck) are wrapped in `timeout` — defaults: `agent.timeout` 3600s, `verification.timeout` 600s. Exit code 124 = killed by timeout

## Boundaries

### Always

- All code, comments, and documentation in English
- `set -euo pipefail` in every script
- Run `shellcheck` on modified .sh files before considering done
- Source libs via `source "$FRAMEWORK_DIR/lib/<name>.sh"`, never relative paths

### Ask first

- Before changing `experiment.yaml` schema (affects all experiments)
- Before modifying `runner.sh` or `orchestrator.sh` interface (condition `setup.sh` contract)
- Before adding new dependencies beyond bash, jq, yq, python3, git

### Never

- Never modify files in `archive/` — those are preserved historical results
- Never hardcode condition names in framework scripts — always read from `experiment.yaml`
- Never add project descriptions, directory structure, or tech stack explanations to this file — the agent can read the code
