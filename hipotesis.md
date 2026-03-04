# Hypotheses to Test

## Hypothesis 1: CLAUDE.md effect on agent performance

**Idea:** The ETH Zurich study (Gloaguen et al., arxiv:2602.11988) claims that context files hurt agent performance. However, the study tested auto-generated files and random developer-committed files of unknown quality — not hand-curated files written per vendor guidelines. A well-crafted CLAUDE.md containing only non-discoverable information (build commands, architectural gotchas, boundaries) should improve task quality.

**Hypothesis:** A hand-curated CLAUDE.md with non-discoverable "landmines" improves agent task quality without degrading success rate.

**Experiment:** `experiments/001-claude-md-effect/` — 2 conditions (with/without CLAUDE.md), typescript-eslint monorepo, ESLint rule bug fix task, 5 runs per condition with interleaving.

**Status:** 🔲 Not tested

**Result:** —

---

## Hypothesis 2: Reduce CLAUDE.md/AGENTS.md to <100 lines

**Idea:** Every line in a context file competes for limited attention. LLMs follow roughly 150 instructions reliably; beyond that, adherence degrades across all instructions — not just the excess. Generated CLAUDE.md/AGENTS.md files must be short (under 100 lines for root files), hand-curated, and contain only what the agent cannot discover from the codebase itself.

**Hypothesis:** Reducing the CLAUDE.md/AGENTS.md file to under 100 lines will improve instruction adherence.

**Experiment:** Cut CLAUDE.md/AGENTS.md file to <100 lines and run benchmark.

**Status:** 🔲 Not tested

**Result:** —

---

## Hypothesis 3: Remove discoverable information from context files

**Idea:** Do not restate what the agent can learn by reading the repository — directory structure, tech stack from config files, framework conventions from existing code. Research shows that when context files duplicate information already in the repository, they increase inference cost 20%+ while degrading task success. Context files earn their cost only when they contain what the agent cannot discover: non-obvious commands, architectural gotchas, and conventions that break silently if violated.

**Hypothesis:** Removing discoverable information from CLAUDE.md/AGENTS.md will reduce inference cost and improve task success rate.

**Experiment:** Strip all discoverable content (directory structure, tech stack, framework conventions) from CLAUDE.md/AGENTS.md, keep only non-obvious commands and architectural gotchas, and run benchmark.

**Status:** 🔲 Not tested

**Result:** —
