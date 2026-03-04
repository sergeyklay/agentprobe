---
name: creating-experiment
description: "Create a new AgentProbe experiment through guided interview. Use when the user wants to add a hypothesis, create a benchmark, set up a new test, or says 'new experiment'. Handles experiment.yaml, hypothesis.md, task-prompt.txt, condition setup scripts, and directory scaffolding. Do NOT use for running existing experiments or analyzing results."
---

# Creating an AgentProbe Experiment

Generate a complete, runnable experiment directory by interviewing the user about their hypothesis, then scaffolding all required files.

## Interview Protocol

Conduct the interview in **5 rounds**. Use AskUserQuestion for structured choices. Ask in the user's language, write all generated files in English.

### Round 1: Hypothesis

Ask these questions (adapt phrasing to context):

1. **What are you testing?** — The hypothesis in one sentence. Examples:
   - "CLAUDE.md under 100 lines improves instruction adherence"
   - "Removing discoverable info from context files reduces cost"
   - "Adding skills improves task completion rate"

2. **What is the counter-hypothesis?** — What would disprove it? If the user is unsure, suggest: "No significant difference between conditions" as default.

3. **How many conditions?** — Minimum 2 (control + treatment). Each condition is a different setup applied to the same task. Examples:
   - 2 conditions: without CLAUDE.md / with CLAUDE.md
   - 3 conditions: no context / short context / full context

4. **Name each condition** — Short kebab-case names. Examples: `no-claude-md`, `short-claude-md`, `full-claude-md`.

### Round 2: Task and Project

5. **What project will the agent work on?** — Local path to a git repo with dependencies installed. Must have a `.git` directory.

6. **What base commit?** — The commit SHA to reset to for each run. Must be a clean, working state.

7. **What task should the agent perform?** — The exact prompt. This must be:
   - Specific enough to be actionable
   - Identical across all conditions
   - Verifiable (has tests, produces measurable output)

8. **How to verify success?** — Commands to run after the agent finishes:
   - Test command (e.g., `npx vitest run path/to/test.ts`)
   - Typecheck command (optional, e.g., `npx tsc --noEmit`)
   - Test output parser: `vitest` or `jest` (for extracting pass/fail counts)
   - Note: `$AGENTPROBE_BASE_COMMIT` is available in test_command — use it for `git diff` instead of `HEAD~1` (the agent may not have committed)

### Round 3: Agent Configuration

9. **Which agent CLI?** — Default: `claude`. Could also be `cursor` or another CLI.

10. **Which model?** — Default: `claude-sonnet-4-6`. Options depend on the CLI.

11. **Max turns?** — Default: 50. Higher for complex tasks, lower for simple ones.

12. **How many runs per condition?** — Default: 5. Minimum 3 for any statistical meaning. Recommend 5+ citing Atil et al. (arxiv:2408.04667): even at temperature=0, accuracy varies up to 15% between runs.

13. **Interleave conditions?** — Default: true (A-B-A-B). Explain: controls for API latency drift over multi-hour experiment windows.

### Round 4: Condition Artifacts

For each condition, ask:

14. **What files should be placed in the worktree?** — Examples:
    - A specific CLAUDE.md variant
    - Modified .cursor/rules/*.md files
    - A custom settings.json
    - Nothing (control condition)

15. **Any other setup needed?** — Commands to run before the agent starts (beyond file placement). Usually none.

If the user provides a CLAUDE.md or other artifact inline, save it to the condition's `artifacts/` directory.

### Round 5: References and Context

This is the final round. Its purpose is to ground the experiment in evidence and give the agent material for writing a well-cited hypothesis.md.

16. **Do you have references that support this hypothesis?** — Ask for any of:
    - arxiv.org paper URLs (e.g., `https://arxiv.org/abs/2602.11988`)
    - GitHub repository URLs (e.g., `https://github.com/karpathy/llm-council`)
    - Blog posts, documentation links, or other web sources
    - Prior AgentProbe experiment results (e.g., `archive/v0-claude-md-effect/`)

17. **Any additional context the agent should understand?** — Free-form notes:
    - Why this hypothesis matters
    - What prior work has been done
    - Known limitations or caveats
    - Specific findings from papers (quotes, numbers, conclusions)

**Processing references:**

For each URL provided:
- **arxiv.org links**: Fetch the paper using WebFetch to extract title, authors, abstract, and key findings. Include these in hypothesis.md as properly formatted citations.
- **GitHub links**: Fetch the README to understand the project's purpose and relevance. Summarize in hypothesis.md.
- **Other URLs**: Fetch and extract the relevant claims or data points.

If the user provides no references, that is acceptable — not every hypothesis needs prior literature. But always ask.

**Integrating references into hypothesis.md:**

Add a `## References` section at the end of hypothesis.md with numbered citations. In the `## Claim` and `## Counter-claim` sections, cite relevant findings inline using `[N]` notation. This makes the experiment self-documenting and auditable.

Example:

```markdown
## Claim

Reducing CLAUDE.md to under 100 lines improves instruction adherence.
LLMs follow roughly 150 instructions reliably; beyond that, adherence
degrades across all instructions [1]. Generated context files increase
inference cost by 20%+ while degrading task success [2].

## References

- [1] Anthropic. "Claude Code Best Practices" — https://docs.anthropic.com/...
- [2] Gloaguen et al. "Evaluating AGENTS.md" — [arxiv:2602.11988](https://arxiv.org/abs/2602.11988)
- [3] Karpathy. "LLM Council" — [github.com/karpathy/llm-council](https://github.com/karpathy/llm-council)
```

## Generation

After the interview, generate the experiment directory using `scripts/scaffold.sh`.

### Directory Structure

```
experiments/<NNN>-<name>/
├── experiment.yaml
├── hypothesis.md
├── task-prompt.txt
└── conditions/
    ├── <condition-1>/
    │   ├── setup.sh
    │   └── artifacts/          # only if artifacts exist
    │       └── <files>
    ├── <condition-2>/
    │   ├── setup.sh
    │   └── artifacts/
    └── ...
```

### Experiment Number

Auto-detect the next number by scanning `experiments/` for existing `NNN-*` directories. Use the next sequential number, zero-padded to 3 digits.

### experiment.yaml Template

```yaml
name: "<hypothesis name>"
version: 1

hypothesis: |
  <multi-line hypothesis from interview>

project:
  local_path: "<path from interview>"
  base_commit: "<commit from interview>"

agent:
  cli: "<agent cli>"
  model: "<model>"
  max_turns: <max_turns>
  output_format: "stream-json"
  extra_flags:
    - "--dangerously-skip-permissions"
    - "--verbose"

runs:
  per_condition: <N>
  interleave: <true|false>

conditions:
  - name: "<condition-1>"
    setup: "conditions/<condition-1>/setup.sh"
  - name: "<condition-2>"
    setup: "conditions/<condition-2>/setup.sh"

task:
  prompt_file: "task-prompt.txt"
  verification:
    # $AGENTPROBE_BASE_COMMIT is available — use instead of HEAD~1
    test_command: "<test command or empty>"
    typecheck_command: "<typecheck command or empty>"
    test_parser: "<vitest|jest>"

statistics:
  confidence_level: 0.95
```

### setup.sh Template

For conditions **without** artifacts (control):

```bash
#!/usr/bin/env bash
set -euo pipefail
WORKTREE_DIR="${1:?Usage: setup.sh <worktree_dir>}"
# Control condition: ensure no context file present
rm -f "$WORKTREE_DIR/CLAUDE.md" "$WORKTREE_DIR/.cursorrules"
echo "  [setup] Control: <condition-name>"
```

For conditions **with** artifacts:

```bash
#!/usr/bin/env bash
set -euo pipefail
WORKTREE_DIR="${1:?Usage: setup.sh <worktree_dir>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/artifacts/<filename>" "$WORKTREE_DIR/<filename>"
echo "  [setup] <condition-name>: <filename> placed"
```

### hypothesis.md Template

```markdown
# Hypothesis: <name>

## Claim

<1-2 sentences stating what we expect to find>

## Counter-claim

<What would disprove the hypothesis>

## Conditions

<List each condition and what makes it different>

## Metrics

- Tests pass/fail (binary)
- Duration (ms)
- Token usage (input, output, cache)
- Tool calls count
- Typecheck pass/fail
```

## Post-Generation

After generating all files:

1. Run `chmod +x` on all setup.sh scripts
2. Validate by running: `bash framework/orchestrator.sh experiments/<new>/ --dry-run`
3. Show the dry-run output to the user
4. If validation fails, fix the issue and re-run

## Defaults Summary

| Parameter | Default | Rationale |
|-----------|---------|-----------|
| Runs per condition | 5 | Atil et al.: up to 15% variance at temp=0 |
| Interleave | true | Controls API latency drift |
| Max turns | 50 | Sufficient for most ESLint/code tasks |
| Model | claude-sonnet-4-6 | Cost-effective for benchmarking |
| Confidence level | 0.95 | Standard for scientific reporting |
| Output format | stream-json | Required for metrics extraction |
