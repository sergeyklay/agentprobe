# AgentProbe

A benchmarking framework for testing hypotheses about AI coding agent behavior.
Each hypothesis is an independent, reproducible experiment with its own config,
input artifacts, and reports.

## Quick Start

```bash
# Run any experiment (dry-run to preview schedule without executing)
bash framework/orchestrator.sh experiments/<experiment-name>/ --dry-run

# Run for real
bash framework/orchestrator.sh experiments/<experiment-name>/

# Example: run the CLAUDE.md effect experiment
bash framework/orchestrator.sh experiments/001-claude-md-effect/
```

## Architecture

```plaintext
agentprobe/
├── framework/                          # Reusable benchmark engine
│   ├── orchestrator.sh                 # Runs N × M experiment from config
│   ├── runner.sh                       # Single agent session in isolated worktree
│   ├── report-generator.sh             # Markdown report + summary.json
│   ├── metrics-collector.sh            # Extract metrics from stream-json logs
│   └── lib/                            # Shared libraries
│       ├── git-isolation.sh            # git worktree create/cleanup
│       ├── json-utils.sh               # JSON construction via jq
│       ├── stats.sh                    # mean, median, stddev, 95% CI, Cohen's d
│       └── validation.sh               # Config + environment validation
│
├── experiments/                        # One directory per hypothesis
│   ├── 001-claude-md-effect/           # Does CLAUDE.md help or hurt?
│   │   ├── experiment.yaml
│   │   ├── hypothesis.md
│   │   ├── conditions/
│   │   └── results/
│   ├── 002-context-file-length/        # (planned) <100 lines vs full
│   ├── 003-discoverable-vs-landmines/  # (planned) Strip discoverable info
│   ├── ...
│   ├── ...
│   ├── ...
│   └── xxx-your-hypothesis/            # Add your own — no framework changes
│
├── research/                           # Background research and references
├── archive/                            # Preserved results from prior versions
└── .tasks/                             # Task specs and roadmap
```

## How It Works

1. `orchestrator.sh` reads `experiment.yaml`, validates config and environment
2. Builds a run schedule with optional interleaving (A-B-A-B instead of AAA-BBB)
3. For each run, `runner.sh` creates an isolated git worktree, runs a condition
   setup script, executes the agent headless, captures metrics, and cleans up
4. `report-generator.sh` aggregates results with 95% CI and Cohen's d effect sizes

## Adding a New Experiment

### Option A: Agent-assisted (recommended)

The project includes a `creating-experiment` skill that conducts a guided
interview and scaffolds all required files. In Claude Code, say:

> "new experiment" or "create experiment"

The agent will ask about your hypothesis, conditions, task, verification
commands, and references — then generate `experiment.yaml`, `hypothesis.md`,
`task-prompt.txt`, condition setup scripts, and run a dry-run to validate.

Review the generated files before running. The agent accelerates scaffolding
but the human is responsible for experiment design quality.

### Option B: Manual

```bash
mkdir -p experiments/002-my-hypothesis/conditions/{control,treatment}

# 1. Write experiment.yaml (see experiments/001-claude-md-effect/ for reference)
# 2. Write hypothesis.md
# 3. Write task-prompt.txt
# 4. Write conditions/<name>/setup.sh for each condition
# 5. Place artifacts in conditions/<name>/artifacts/ if needed
# 6. Run:
bash framework/orchestrator.sh experiments/002-my-hypothesis/
```

No framework code changes needed in either case.

## Isolation Model

Each agent run gets a fresh git worktree detached at the base commit.
The main repository is never modified. This ensures:

- Zero context leakage between runs
- Parallel execution capability
- No risk of destroying in-progress work

## Statistical Rigor

- Multiple runs per condition (N≥5 recommended)
- Mean, median, stddev for all numeric metrics
- 95% confidence intervals (t-distribution for small N)
- Cohen's d effect size for pairwise comparisons
- Interleaving controls for API latency drift

## Prerequisites

### Required tools

| Tool      | Version         | Purpose                                                    |
| --------- | --------------- | ---------------------------------------------------------- |
| `bash`    | 4.0+            | Script execution                                           |
| `git`     | 2.15+           | Worktree isolation (`git worktree` support)                |
| `claude`  | any             | Claude Code CLI — the agent under test                     |
| `jq`      | 1.6+            | JSON processing in metrics and reports                     |
| `yq`      | 4.x (mikefarah) | YAML config parsing (`experiment.yaml`)                    |
| `python3` | 3.8+            | Statistics (CI, Cohen's d), log parsing, report generation |

### Per-experiment requirements (depend on the target project)

| Tool           | When needed                           |
| -------------- | ------------------------------------- |
| `node`         | TypeScript/JavaScript projects        |
| `pnpm` / `npm` | Package management for target project |

### Setup

1. Install and authenticate the [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
2. Ensure `jq`, `yq`, `python3`, `git` are in `$PATH`
3. Clone the target project and install its dependencies
4. Configure `experiment.yaml` with the correct `project.local_path` and `project.base_commit`

## Design Rationale and References

The design decisions in AgentProbe are grounded in peer-reviewed research on
LLM evaluation methodology. This section documents why specific approaches
were chosen.

### Why N≥5 runs per condition?

Atil et al. found that even at temperature=0, LLM accuracy varies **up to 15%**
across runs, with a gap between best and worst reaching 70%.
Yuan et al. (NeurIPS 2025 Oral) traced the root cause to BF16 floating-point
precision — the standard for commercial API deployments.

A single run tells you nothing about an agent's true capability. Multiple runs
with confidence intervals are a non-negotiable requirement.

> Atil et al. "Non-Determinism of 'Deterministic' LLM Settings" — [arxiv:2408.04667](https://arxiv.org/abs/2408.04667)
> Yuan et al. "Understanding and Mitigating Numerical Sources of Nondeterminism in LLM Inference" — [arxiv:2506.09501](https://arxiv.org/abs/2506.09501)
> Blackwell et al. "Towards Reproducible LLM Evaluation: Quantifying Uncertainty in LLM Benchmark Scores" — [arxiv:2410.03492](https://arxiv.org/abs/2410.03492)

### Why interleaving (A-B-A-B) instead of sequential blocks?

API latency and model behavior drift over multi-hour experiment windows.
Sequential blocks (all A runs, then all B) conflate temporal drift with
condition effects. AgentBench (ICLR 2024) addresses this by randomizing
evaluation order across environments.

> Liu et al. "AgentBench: Evaluating LLMs as Agents" — [arxiv:2308.03688](https://arxiv.org/abs/2308.03688)

### Why git worktree for isolation?

TheAgentCompany uses self-hosted Docker environments for full isolation.
For code-only tasks, `git worktree` provides filesystem isolation without
Docker overhead. Each run gets a detached worktree at the base commit;
the main repository is never modified; worktrees are destroyed after metrics
are captured.

> Xu et al. "TheAgentCompany: Benchmarking LLM Agents on Consequential Real World Tasks" — [arxiv:2412.14161](https://arxiv.org/abs/2412.14161)

### Why separate cache token tracking?

Claude Code uses prompt caching aggressively. Lumping `cache_read_input_tokens`
into `input_tokens` makes it impossible to distinguish "the agent read more
context" from "the cache was warm". Separate tracking is critical for hypotheses
about context file content (where cache behavior differs between conditions).

### Why Cohen's d for effect size?

Success rate alone hides operationally significant differences. Rabanser et al.
propose 12 metrics across 4 dimensions (consistency, robustness, predictability,
safety). Cohen's d quantifies whether an observed difference is practically
meaningful — not just statistically present. The SWE-Bench Illusion paper
demonstrates that without rigorous evaluation, 32.67% of apparent successes
are artifacts of data contamination.

> Rabanser et al. "Towards a Science of AI Agent Reliability" — [arxiv:2602.16666](https://arxiv.org/abs/2602.16666)
> Liang et al. "The SWE-Bench Illusion" — [arxiv:2506.12286](https://arxiv.org/abs/2506.12286)

### Why shell scripts and not Python/Node orchestration?

The orchestrator must not influence the agent under test. Shell scripts are
transparent, auditable, and have zero runtime that could leak into the
agent's context. A Python orchestrator importing LLM libraries would risk
polluting the environment. The hybrid approach — shell for data collection,
optional LLM for post-analysis — follows the scientific principle of blind
data collection followed by informed analysis.

> Li et al. "LLMs-as-Judges: A Comprehensive Survey" — [arxiv:2412.05579](https://arxiv.org/abs/2412.05579)

### Motivating research

The project was motivated by the ETH Zurich study claiming that context files may
hurt agent performance. The full pre-registration document with literature review
and methodology is in [`research/001-claude-md-effect-design.md`](research/001-claude-md-effect-design.md).
Our first experiment (archived in `archive/v0-claude-md-effect/`) tested this
claim with a hand-curated `CLAUDE.md` on a real typescript-eslint task and
found a more nuanced picture: both conditions achieved 100% test success, but
the `CLAUDE.md` condition produced deeper edge-case coverage at the cost of
155% more time.

> Gloaguen et al. "Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?" — [arxiv:2602.11988](https://arxiv.org/abs/2602.11988)
> Chatlatanagulchai et al. "Agent READMEs: An Empirical Study of Context Files for Agentic Coding" — [arxiv:2511.12884](https://arxiv.org/abs/2511.12884)
> Jiang & Nam "Beyond the Prompt: An Empirical Study of Cursor Rules" — [arxiv:2512.18925](https://arxiv.org/abs/2512.18925)
