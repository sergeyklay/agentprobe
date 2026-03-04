---
name: creating-experiment
description: >
  Use when creating a new AgentProbe experiment, adding a hypothesis,
  setting up a benchmark, or when the user says "new experiment" or
  "create experiment". Handles full experiment scaffolding with
  optional auto-discovery of open-source target projects.
  Do NOT use for running experiments or analyzing results.
---

# Creating an AgentProbe Experiment

## Workflow

Conduct a 5-round interview, then scaffold the experiment directory.
Use AskUserQuestion for structured choices. Ask in the user's language,
write all generated files in English.

### Round 1: Hypothesis

1. Ask what the user is testing — one sentence hypothesis
2. Ask for the counter-hypothesis (default: "No significant difference")
3. Ask how many conditions — minimum 2 (control + treatment)
4. Ask for kebab-case names for each condition

### Round 2: Task and Project

1. Ask where the agent will work — offer two options:
   - **Specific project**: user provides local path to a git repo
   - **Find a project**: run the discovery procedure in
     `references/project-discovery.md`, present 3-5 candidates, let user choose

2. Ask for the base commit SHA (if auto-discovered, use HEAD after cloning)

3. Ask if the project needs a setup command to run in each worktree
   before the agent starts (e.g., `pnpm install --frozen-lockfile`,
   `pip install -e .`). Git worktrees only contain tracked files —
   dependencies must be installed explicitly. Optional field:
   `project.setup_command`

4. Ask what task the agent should perform — must be:
   - Specific enough to be actionable
   - Identical across all conditions
   - Verifiable with tests
   - If auto-discovered, rewrite the issue as an agent instruction
     (imperative form, verification steps, no solution hints)

5. Ask how to verify success:
   - Test command (e.g., `npx vitest run path/to/test.ts`)
   - Typecheck command (optional)
   - Test parser: `vitest` or `jest`
   - `$AGENTPROBE_BASE_COMMIT` is available in test_command — use it
     instead of `HEAD~1` (agent may not have committed)
   - If auto-discovered, infer from package.json scripts or CI config

### Round 3: Agent Configuration

1. Ask which agent CLI (default: `claude`)
2. Ask which model (default: `claude-sonnet-4-6`)
3. Ask max turns (default: 50)
4. Ask agent timeout in seconds (default: 3600 = 1 hour)
5. Ask verification timeout in seconds (default: 600 = 10 min) —
   this prevents hung tests/typecheck from blocking the experiment
6. Ask runs per condition (default: 5, minimum 3 — at temperature=0
   accuracy varies up to 15% between runs per Atil et al. arxiv:2408.04667)
7. Ask whether to interleave conditions (default: true, A-B-A-B pattern
    to control for API latency drift)

### Round 4: Condition Artifacts

For each condition:

1. Ask what files to place in the worktree:
   - CLAUDE.md variant, .cursor/rules/\*.md, settings.json, or nothing
2. Ask if any other setup is needed beyond file placement

If the user provides artifact content inline, save it to the condition's
`artifacts/` directory.

### Round 5: References

1. Ask for references supporting the hypothesis:
   - arxiv.org URLs, GitHub URLs, blog posts, prior AgentProbe results
2. Ask for any additional context (why it matters, prior work, caveats)

For each URL provided:

- **arxiv.org**: fetch with WebFetch, extract title, authors, key findings
- **GitHub**: fetch README, extract purpose and relevance
- **Other URLs**: extract relevant claims or data points

Integrate references into hypothesis.md using `[N]` inline citations
and a `## References` section. See `assets/hypothesis.md.tmpl` for format.

## Scaffolding

After the interview, generate the experiment:

1. Detect next experiment number:
   ```bash
   bash scripts/scaffold.sh <experiment-slug> experiments/
   ```
2. Create condition directories:
   ```bash
   mkdir -p experiments/<NNN>-<name>/conditions/<condition>/artifacts
   ```
3. Generate files from templates in `assets/`:
   - `experiment.yaml` from `assets/experiment.yaml.tmpl`
   - `hypothesis.md` from `assets/hypothesis.md.tmpl`
   - `task-prompt.txt` from interview answers
   - `setup.sh` per condition from `assets/setup-control.sh.tmpl`
     or `assets/setup-treatment.sh.tmpl`
   - Artifact files in `conditions/<name>/artifacts/`
4. Make setup scripts executable:
   ```bash
   chmod +x experiments/<NNN>-<name>/conditions/*/setup.sh
   ```

## Validation

1. Run dry-run to verify:
   ```bash
   bash framework/orchestrator.sh experiments/<NNN>-<name>/ --dry-run
   ```
2. Show the output to the user
3. If validation fails, diagnose and fix, then re-run
4. If validation passes, confirm the experiment is ready

## Defaults

| Parameter            | Default           | Rationale                                        |
| -------------------- | ----------------- | ------------------------------------------------ |
| Runs per condition   | 5                 | Atil et al.: up to 15% variance at temp=0        |
| Interleave           | true              | Controls API latency drift                       |
| Max turns            | 50                | Sufficient for most code tasks                   |
| Agent timeout        | 3600s (1 hour)    | Prevents hung agent from blocking experiment     |
| Verification timeout | 600s (10 min)     | Prevents hung tests/typecheck from blocking runs |
| Model                | claude-sonnet-4-6 | Cost-effective for benchmarking                  |
| Confidence level     | 0.95              | Standard for scientific reporting                |
| Output format        | stream-json       | Required for metrics extraction                  |
