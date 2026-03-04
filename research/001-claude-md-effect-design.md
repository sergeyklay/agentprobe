# Experiment: Prove or Disprove the Harm of AGENTS.md

## Context and Motivation

The ETH Zurich study (Gloaguen et al., arXiv:2602.11988) claims that context files (AGENTS.md / CLAUDE.md) either degrade agent task-solving quality (-2% for LLM-generated ones) or produce unstable results (+4% for human-written ones). A blogger on [sulat.com](https://sulat.com/p/agents-md-hurting-you) turned this into the clickbait headline "your AGENTS.md might be hurting you".

Our position: the study has serious methodological problems, and its conclusions do not apply to properly written context files in real-world projects. We aim to prove this (or honestly disprove it) through a reproducible experiment.

### Why the Original Study Is Problematic

1. **The SWE-bench benchmark is disqualified.** On February 23, 2026, OpenAI published an audit showing that 59.4% of tasks contain test-design issues that reject correct solutions. Contamination was detected in all frontier models (GPT-5.2, Claude Opus 4.5, Gemini 3 Flash). OpenAI officially discontinued use of SWE-bench Verified.

2. **The study tested something different from what vendors recommend.** Two conditions in the experiment: (a) LLM-generated files via `/init` — Anthropic explicitly warns that this is a starting point, not a final product; (b) "developer-committed files" — random files from GitHub repositories of uncontrolled quality. Neither condition tested a file written according to vendor recommendations.

3. **Task type — bug fixes only.** SWE-bench measures bug fixes in open-source Python repositories. This does not cover feature development, refactoring, or migrations — tasks where a context file is most useful.

---

## Part 1: What Should Be in AGENTS.md

### Source Consensus

Analysis of recommendations from the following sources:

- **Anthropic** (Claude Code docs, CLAUDE.md best practices)
- **OpenAI** (Codex AGENTS.md documentation, prompting guide)
- **GitHub** (analysis of 2,500+ repositories, Matt Nigh)
- **Addy Osmani** (Google, series of articles on AGENTS.md)
- **agents.md** (Agentic AI Foundation / Linux Foundation specification)
- **HumanLayer** (study of Claude Code system prompts)
- **Community** (rosmur best practices, claudelog.com)

### The Golden Rule of Filtering (Addy Osmani)

> "Can the agent discover this on its own by reading your code? If yes, delete it."

The ETH Zurich data confirms this principle: when they removed all documentation from repositories and left only LLM-generated context files, performance increased by 2.7%. The files aren't useless in a vacuum — they're useless when the information already exists in the repository.

### What SHOULD Be in the File (Things the Agent Cannot Discover on Its Own)

#### 1. Non-obvious Commands and Tools ("Landmines")

Things that look normal but will blow up if the agent takes the obvious path:

```markdown
## Commands

- Use `pnpm` (not npm/yarn) - the lockfile is pnpm-lock.yaml
- Run tests: `pnpm vitest run` (NOT `pnpm test` - it runs the full CI suite including e2e)
- Run single test: `pnpm vitest run src/path/to/file.test.ts`
- Typecheck: `pnpm tsc --noEmit`
- Lint: `pnpm eslint --fix src/`
```

Study data: mentioning `uv` in a context file led to its usage 1.6 times per task vs <0.01 without mention. This is a concrete, measurable impact.

#### 2. Architectural "Landmines" (Conventions That Break If Violated)

```markdown
## Architecture gotchas

- The `legacy/` directory is deprecated but 3 production modules still import from it. Do NOT refactor these imports.
- Auth module uses custom middleware chain - do not replace with standard Express middleware.
- All API responses go through `src/utils/response-wrapper.ts` - never return raw objects from controllers.
- Database migrations are in `drizzle/migrations/` - never modify existing migration files, only create new ones.
```

#### 3. Code Style That Cannot Be Inferred from Code

```markdown
## Code style

- Error handling: always use `Result<T, E>` pattern from `src/utils/result.ts`, never throw exceptions in business logic
- Imports: group as (1) node builtins, (2) external packages, (3) internal aliases starting with `@/`
- Tests: use `describe/it` style, not `test()`. Always co-locate tests as `*.test.ts` next to source files.
```

#### 4. Three-Level Boundaries (Always / Ask First / Never)

```markdown
## Boundaries

### Always

- Run `pnpm vitest run` after changing any `.ts` file
- Run `pnpm tsc --noEmit` before considering task complete
- Add/update tests for changed behavior

### Ask first

- Before adding new dependencies
- Before modifying database schema
- Before changing public API contracts

### Never

- Never modify files in `src/generated/` - they are auto-generated
- Never commit `.env` files or secrets
- Never remove a failing test without explicit approval
- Never modify existing migration files
```

### What Should NOT Be in the File

- No project structure descriptions (the agent can read the directory tree)
- No technology stack descriptions (the agent can see package.json / tsconfig.json)
- No codebase overview (the agent can read the README and code)
- No framework documentation summaries
- Nothing longer than ~60–100 lines (HumanLayer recommends <60 lines in the root file)

### Critical Context: How Claude Code Processes CLAUDE.md

From the HumanLayer study: Claude Code injects CLAUDE.md contents with the note:

> "IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly relevant to your task."

This means Claude Code actively ignores irrelevant content. The more "filler" in the file, the higher the probability that the agent will also ignore important instructions.

---

## Part 2: Choosing a Project for the Experiment

### Selection Criteria

1. **TypeScript** — familiar stack, representative for the audience
2. **Easy to set up locally** — `git clone` + `pnpm install` + it works
3. **Open issue** — a real task, not synthetic
4. **Issue is sufficiently complex** — not a trivial typo, but not an architectural overhaul either
5. **Has tests** — objective correctness verification is possible
6. **Has "landmines"** — the project has non-obvious conventions the agent can violate
7. **Existing tests for the task** — or the ability to quickly write acceptance criteria
8. **Task is unsolved at the time of the experiment** — to exclude contamination

### Candidate #1: typescript-eslint

**Repository:** `typescript-eslint/typescript-eslint`
**Stack:** TypeScript, monorepo (Nx/Lerna), Vitest, ESLint
**Stars:** 16,000+
**Team size:** active

**Why it fits:**

- Monorepo with many packages — lots of non-obvious inter-package dependencies
- Strict conventions: specific test patterns, unique AST visitor pattern
- Active issue stream with "accepting prs" and "good first issue" labels
- Good test infrastructure — objective verification
- Non-obvious "landmines": tests must be run in a specific package, not globally; specific pattern for creating rules

**Examples of suitable issues:**

- Bug fixes in ESLint rules (false positive/negative)
- Adding new options to existing rules
- Autofix logic fixes

**Potential "landmines" for AGENTS.md:**

- Monorepo: tests are run via `npx jest --selectProjects @typescript-eslint/eslint-plugin`
- AST: must use `ESLintUtils.RuleCreator` for creating rules
- Test patterns: `RuleTester` with specific valid/invalid case format
- Build: `nx build` before running tests in dependent packages

### Candidate #2: Hoppscotch

**Repository:** `hoppscotch/hoppscotch`
**Stack:** TypeScript, Vue 3 + Nuxt, Tailwind, pnpm monorepo
**Stars:** 77,000+

**Why it fits:**

- Very popular, well-structured project
- Vue 3 composition API + TypeScript — many non-obvious patterns
- pnpm workspace monorepo
- 560+ open issues

**Potential problems:**

- Complex setup (requires backend, Docker)
- Many bugs are UI-related — difficult to verify automatically

### Candidate #3: Vitest

**Repository:** `vitest-dev/vitest`
**Stack:** TypeScript, monorepo, Vite
**Stars:** 14,000+

**Why it fits:**

- Pure TypeScript, well tested
- Clear domain area (test framework)
- "Landmines": its own test runner, need to understand how to test a test framework

**Potential problems:**

- Very deep domain area — tasks may be too complex

### Recommendation: typescript-eslint

**Rationale:**

1. **Objective results.** ESLint rules have clear tests: valid cases must not report an error, invalid cases must. No "eyeballing" — tests either pass or they don't.

2. **Rich "landmines."** Monorepo with non-trivial structure, specific rule creation patterns, specific test utilities — ideal for demonstrating the value of a context file.

3. **Reproducibility.** Setup: `git clone && pnpm install` — that's it. No Docker, databases, or external services.

4. **Measurable metrics.** Number of tests passing/failing, number of lint/typecheck errors, time to working solution, number of iterations/tokens.

5. **Task availability.** Many issues with the "accepting prs" label — tasks approved by maintainers.

---

## Part 3: Experiment Design

### Variables

| Variable    | Value                                   |
| ----------- | --------------------------------------- |
| Agent       | Claude Code (or Cursor Agent)           |
| Model       | Claude Sonnet 4.5 (fixed)               |
| Task        | Same issue from typescript-eslint       |
| Condition A | Without AGENTS.md (clean repository)    |
| Condition B | With AGENTS.md (written per guidelines) |
| Prompt      | Identical task text                     |

### Metrics

#### Objective (Uncontroversial)

1. **Tests pass?** (binary metric: yes/no)
2. **Number of test failures** after patch
3. **TypeScript typecheck** passes? (`pnpm tsc --noEmit`)
4. **Lint** passes? (`pnpm eslint`)
5. **Time to first working solution** (in minutes/seconds)
6. **Number of tokens** (input + output)
7. **Number of iterations/tool calls** by the agent

#### Qualitative (For Reinforcement, but May Be Disputed)

8. **Does the code follow project conventions?** (correct RuleTester pattern, imports, etc.)
9. **Does the solution address the root cause?** (not just the symptom)
10. **Is the code PR-ready?** (no extraneous changes, correct scope)

### Protocol

#### Preparation

1. Select a specific issue from typescript-eslint with the "accepting prs" label
2. Fix the repository commit hash
3. Write AGENTS.md according to recommendations (see below)
4. Prepare an identical prompt for both conditions
5. Ensure the issue is unsolved and no open PRs exist

#### Condition A: Without AGENTS.md

1. Clone the repository at the fixed commit
2. Run the agent with the prompt: issue text + "fix this bug"
3. Record: time, tokens, iterations, test results
4. Save the full session log and final diff

#### Condition B: With AGENTS.md

1. Clone the repository at the same commit
2. Add AGENTS.md to the root
3. Run the agent with the same prompt
4. Record the same metrics
5. Save the full log and diff

#### Repetitions

For statistical significance — repeat each condition 3–5 times (model temperature creates variability). This is critically important, as the ETH Zurich study showed instability of results for developer-written files.

### AGENTS.md Template for typescript-eslint

```markdown
# AGENTS.md - typescript-eslint

## Commands

- Install: `pnpm install` (NOT npm/yarn)
- Build all: `npx nx run-many --target=build`
- Build specific package: `npx nx build @typescript-eslint/eslint-plugin`
- Run tests for eslint-plugin: `npx jest --selectProjects @typescript-eslint/eslint-plugin`
- Run single test file: `npx jest --selectProjects @typescript-eslint/eslint-plugin -- path/to/test`
- Typecheck: `npx nx run-many --target=typecheck`
- Lint: `npx nx run-many --target=lint`

## Creating/fixing ESLint rules

- Rules live in `packages/eslint-plugin/src/rules/`
- Tests live in `packages/eslint-plugin/tests/rules/`
- Rule docs live in `packages/eslint-plugin/docs/rules/`
- Use `ESLintUtils.RuleCreator` - never raw `{ create, meta }` objects
- Test pattern: `RuleTester` with `valid: [...]` and `invalid: [...]` arrays
- Invalid cases must specify `errors: [{ messageId: '...' }]`
- If fixing autofix: include `output` field in invalid test cases

## Architecture gotchas

- This is a monorepo. Changes to parser or type-utils require rebuild before plugin tests pass.
- AST types come from `@typescript-eslint/typescript-estree` - use them, not raw ESTree types
- `getParserServices(context)` gives access to TypeScript type checker within rules
- Rule options must have JSON Schema definitions in `meta.schema`

## Boundaries

### Always

- Run the specific package tests after changes
- Run typecheck before considering done
- Follow existing test patterns in the file you're modifying

### Never

- Don't run the full test suite (too slow) - target specific packages
- Don't modify test infrastructure (RuleTester setup, fixtures)
- Don't change rule severity defaults without explicit request
```

### What We Expect to See

**Hypothesis:** With a proper AGENTS.md, the agent will:

1. Immediately use the correct commands (pnpm, nx) instead of trial and error
2. Follow project patterns (RuleCreator, RuleTester format)
3. Spend fewer tokens on exploration and more on solving
4. Reach a working solution faster
5. Produce code more ready for PR (correct style, correct scope)

**Alternative hypothesis (if the ETH Zurich study is right):** AGENTS.md will provide no significant improvement or will worsen the result, because:

- The agent will find the necessary commands in package.json/Makefile anyway
- The additional context will create an "attention tax"
- The agent will be "bound" to instructions instead of solving flexibly

---

## Part 4: How to Make Results Indisputable

### The Subjectivity Problem

The main weakness of any single-task experiment is "well, it just happened that way." To minimize this argument:

1. **Multiple runs.** 3–5 runs of each condition. Calculate averages and variance.

2. **Full transparency.** We publish:
   - Full text of AGENTS.md
   - Full prompt
   - Full logs of all sessions
   - All diffs
   - Repository commit hash
   - Agent and model version

3. **Pre-registration.** We describe the hypothesis and metrics BEFORE the experiment (this document IS the pre-registration).

4. **Objective metrics.** Tests pass/fail. Typecheck passes/fails. Number of tokens — a number. Time — a number. No "I think this code is better."

5. **Reproducibility.** Anyone can repeat the experiment with the same inputs.

### What We Consider "Proof"

- If **all 3–5 runs with AGENTS.md** produce passing tests, while **at least 1–2 without AGENTS.md** produce failing tests or an incorrect approach — that is a strong signal.
- If with AGENTS.md the agent **consistently** uses 30%+ fewer tokens/time — that is a strong efficiency signal.
- If there is no difference or it falls within variability — that is also an honest result, supporting part of the ETH Zurich conclusions.

### What We Are NOT Proving

- We are not proving that AGENTS.md helps always and everywhere
- We are not proving that the ETH Zurich study is entirely wrong
- We are proving (or disproving) a specific thesis: **a properly written context file (minimal, hand-crafted, with real "landmines") helps the agent solve tasks better in a real project**

---

## Part 5: Next Steps

### Immediate Actions

1. [ ] Select a specific issue from typescript-eslint (or an alternative project)
2. [ ] Clone the repository and verify the setup works
3. [ ] Study the project conventions and write the final AGENTS.md
4. [ ] Formulate the exact prompt for the agent
5. [ ] Conduct a test run for calibration

### Running the Experiment

6. [ ] Run condition A (without AGENTS.md) x 3–5 times
7. [ ] Run condition B (with AGENTS.md) x 3–5 times
8. [ ] Collect and analyze metrics

### Presenting Results

9. [ ] Comparative metrics table
10. [ ] Visualization (presentation slides)
11. [ ] Conclusions and recommendations for the team

---

## Appendix: Sources

### Research

- Gloaguen et al. "AGENTS.md" (arXiv:2602.11988, ETH Zurich, Feb 2025)
- Lulla et al. "Accelerating Agentic Reasoning" (arXiv:2501.15560, Jan 2025)
- OpenAI "Why SWE-bench Verified no longer measures frontier coding capabilities" (Feb 23, 2026)
- Liu et al. "Lost in the Middle" (2024) — U-shaped attention in LLMs
- SWE-bench Pro audit (LessWrong, 2026) — test-design issues in the Pro version

### Vendor Recommendations

- Anthropic: Claude Code Best Practices (code.claude.com/docs/en/best-practices)
- OpenAI: Custom instructions with AGENTS.md (developers.openai.com/codex/guides/agents-md)
- OpenAI: Codex Prompting Guide (developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide)

### Analysis and Community

- GitHub Blog: "How to write a great agents.md" — analysis of 2,500+ repositories (Matt Nigh, Nov 2025)
- Addy Osmani: "Stop Using /init for AGENTS.md" (addyosmani.com/blog/agents-md)
- Addy Osmani: "Self-Improving Coding Agents" (addyosmani.com/blog/self-improving-agents)
- HumanLayer: "Writing a good CLAUDE.md" (humanlayer.dev/blog/writing-a-good-claude-md)
- agents.md specification (Agentic AI Foundation / Linux Foundation)
- rosmur: Claude Code Best Practices (rosmur.github.io/claudecode-best-practices)
- Sulat.com: "The research is in: your AGENTS.md might be hurting you" (blog post analyzed in this experiment)
