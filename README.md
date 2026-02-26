# CLAUDE.md Effect Experiment

## Quick Start

```bash
# 1. Copy this directory to your server
scp -r agentprobe/ user@server:~/work/agentprobe/

# 2. SSH to server, cd to agentprobe dir
cd ~/work/agentprobe

# 3. Make scripts executable
chmod +x run-experiment.sh generate-report.sh

# 4. Run (defaults: 3 runs per condition, sonnet 4.5)
./run-experiment.sh

# Or with custom settings:
./run-experiment.sh --runs 4 --project-dir ~/work/typescript-eslint
```

## What it does

1. Records base commit and branch of `typescript-eslint`
2. Runs **N** Claude Code headless sessions WITHOUT `CLAUDE.md` (Condition A)
3. Runs **N** Claude Code headless sessions WITH `CLAUDE.md` (Condition B)
4. Each run:
   - Resets repo to base commit
   - Creates a new branch
   - Runs `claude -p` with the task prompt (identical for both)
   - Collects: duration, tokens, tool calls, test results, typecheck, diff
   - Saves metrics as JSON
5. Generates `results/report.md` with comparative analysis

## Files

| File                 | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| `run-experiment.sh`  | Main orchestrator                                       |
| `generate-report.sh` | Processes metrics into report.md                        |
| `task-prompt.txt`    | Task given to the agent (identical for both conditions) |
| `CLAUDE.md`          | Context file used only in Condition B                   |
| `README.md`          | This file                                               |

## Issues from previous attempt (report.md analysis)

### What went wrong before and how this version fixes it

1. **Single run per condition (N=1)** - Previous experiment ran each condition once.
   One data point is insufficient. This version defaults to 3 runs.

2. **Bug was too simple** - The `no-unnecessary-type-conversion` zero-args crash
   was trivially solvable. Both agents produced byte-identical fixes. This version
   uses a more nuanced task (type narrowing edge case in `no-unnecessary-type-assertion`)
   that requires deeper investigation.

3. **Duration variance not accounted for** - The 37% speedup had no error bars.
   Multiple runs allow calculating mean, median, and stddev.

4. **Task prompt included file paths** - Giving exact paths reduces the value
   of CLAUDE.md's navigation guidance. This version describes the bug but doesn't
   give exact file locations (though the rule name is given).

5. **No automated test verification** - Previous experiment manually checked results.
   This version automatically runs vitest and typecheck after each agent session.

6. **No structured logging** - Previous experiment relied on manual observation.
   This version captures stream-json output and parses it for token/tool metrics.

7. **Git gpgsign blocked commits** - Previous setup might have required GPG.
   This version explicitly sets `commit.gpgsign false` and uses anonymous
   git config before each run.

8. **CLAUDE.md too short (40 lines)** - While concise is good, the previous
   file may have been too minimal. This version includes more actionable
   "landmine" information about the monorepo.

### What worked well before (kept)

- Using `pnpm` / `vitest` commands in CLAUDE.md
- Conventional commit format guidance
- Keeping CLAUDE.md under 60 lines
- Testing the same model for both conditions
- Clean branch per condition

## Prerequisites

- Claude Code CLI installed and authenticated
- `typescript-eslint` cloned at `~/work/typescript-eslint` with `pnpm install` done
- `asdf` configured with Node.js 20.9.0
- `~/.profile` sourced (contains asdf paths)
- `~/.claude/settings.json` properly configured

## Configuration

Override defaults via CLI args:

```bash
./run-experiment.sh \
  --runs 4 \
  --project-dir /path/to/typescript-eslint \
  --model claude-sonnet-4-5-20250929 \
  --max-turns 50
```

## Output Structure

```plaintext
results/
  experiment-config.json    # Experiment parameters
  CLAUDE.md.reference       # Copy of CLAUDE.md used
  task-prompt.reference     # Copy of task prompt used
  aggregated.json           # All metrics combined
  report.md                 # Generated report
  without_run1_metrics.json # Per-run metrics
  without_run2_metrics.json
  ...
  with_run1_metrics.json
  with_run2_metrics.json
  ...
  logs/
    without_run1.json       # Full Claude Code session log
    without_run2.json
    ...
    with_run1.json
    with_run2.json
    ...
  diffs/
    without_run1.diff       # Git diff of changes
    ...
```
