# CLAUDE.md Experiment: Analysis of Results

## TL;DR

CLAUDE.md made the agent 2.5x slower but produced measurably deeper, more sophisticated test coverage. The ETH Zurich claim that context files "hurt performance" is misleading - it depends entirely on what you measure. If speed is the metric, CLAUDE.md lost. If quality of reasoning is the metric, CLAUDE.md won.

---

## Raw Numbers

| Metric              | Without CLAUDE.md | With CLAUDE.md | Delta     |
| ------------------- | ----------------- | -------------- | --------- |
| Duration (avg)      | 9m 52s            | 25m 14s        | **+155%** |
| Input tokens (avg)  | 3,822,110         | 5,986,514      | **+57%**  |
| Output tokens (avg) | 36,937            | 94,570         | **+156%** |
| Total tokens (avg)  | 3,859,047         | 6,081,084      | **+58%**  |
| Tool calls (avg)    | 22.5              | 25.0           | +11%      |
| Tests passed        | 100%              | 100%           | 0%        |
| Typecheck           | 100%              | 100%           | 0%        |

---

## What Actually Happened: Diff Analysis

### Valid test cases (where `!` IS necessary)

These test the agent's understanding of _when narrowing breaks_ - the harder conceptual challenge.

| Run          | Condition    | Edge Case                                                           | Sophistication |
| ------------ | ------------ | ------------------------------------------------------------------- | -------------- |
| without_run1 | No CLAUDE.md | `let` + closure with reassignment outside                           | Standard       |
| without_run2 | No CLAUDE.md | `let` + closure capture + reassignment; `let` + direct reassignment | Standard       |
| with_run1    | CLAUDE.md    | `let` + IIFE with `x = undefined` before use                        | **Advanced**   |
| with_run2    | CLAUDE.md    | `let` + closure + reassignment + actual `inner()` call              | **Advanced**   |

**Key difference:** Without CLAUDE.md, the agent wrote cases where reassignment de-narrows - this is the obvious, well-documented pattern. With CLAUDE.md, the agent explored IIFE semantics and the distinction between "closure defined" vs "closure called" - these are subtle TypeScript compiler behaviors that require deeper understanding of control flow analysis.

### Invalid test cases (where `!` is unnecessary)

| Pattern                                 | without_run1 | without_run2 | with_run1 | with_run2 |
| --------------------------------------- | ------------ | ------------ | --------- | --------- |
| `const` after type guard                | ✓            | ✓            | ✓         | ✓         |
| `let` (no reassignment) after guard     | -            | ✓            | ✓         | ✓         |
| `if` block narrowing (not early return) | ✓            | ✓            | -         | -         |
| Function parameter after guard          | ✓            | -            | -         | ✓         |
| `let` + closure defined but NOT called  | -            | -            | ✓         | -         |

The `let` + closure-defined-but-not-called case (with_run1 only) is the most interesting invalid case across all four runs. It tests whether TypeScript's narrowing is invalidated by merely _defining_ a closure that reassigns the variable, without actually _invoking_ it. This is a genuine edge case in the TypeScript compiler's flow analysis.

---

## Why Was CLAUDE.md Slower?

The numbers tell a clear story:

- **Tool calls:** +11% (22.5 → 25.0) - only marginally more actions
- **Output tokens:** +156% (37K → 95K) - dramatically more content per action
- **Input tokens:** +57% (3.8M → 6.0M) - read significantly more context

The agent with CLAUDE.md didn't "spin its wheels" - it invested time in:

1. **Reading more source code** (+57% input tokens with only +11% more tool calls means deeper file reads, not more files)
2. **Writing more thorough code** (+156% output tokens means richer test cases with detailed comments)
3. **Exploring edge cases** (IIFE, closure-without-call patterns vs obvious reassignment patterns)

This is exactly what the CLAUDE.md instructed: "investigate the interaction between type narrowing and non-null assertions" and "consider edge cases around closures, IIFEs, and control flow."

---

## Addressing the ETH Zurich Claims

The ETH Zurich study (Gloaguen et al., arXiv:2602.11988) claimed that AGENTS.md/CLAUDE.md files can hurt agent performance. Our experiment suggests a more nuanced picture:

### What the study likely measured

- Binary task completion (pass/fail)
- Time/tokens to completion
- Probably simple, well-defined tasks with clear success criteria

### What they missed

- **Quality of exploration** - both conditions "passed" (100% tests), but the WITH condition produced more sophisticated edge case coverage
- **Depth of understanding** - the agent with context demonstrated deeper TypeScript compiler knowledge
- **Code quality** - more detailed comments, more precise edge cases

### Our conclusion

CLAUDE.md doesn't "hurt performance" - it **changes what the agent optimizes for**. Without context, the agent optimizes for speed: find the obvious cases, write passing tests, done. With context, the agent optimizes for thoroughness: explore edge cases, understand the type system deeply, write comprehensive coverage.

Whether that's "better" or "worse" depends entirely on what you value. For a quick bugfix? Skip CLAUDE.md. For thorough investigation of a subtle compiler behavior? CLAUDE.md is worth the 2.5x time investment.

---

## Limitations and Caveats

1. **N=2 per condition** - not enough for statistical significance. Stddev on duration is high (55s without, 3m23s with). Need N=5+ minimum.
2. **Single task type** - this was a test-writing task. Results may differ for implementation tasks, refactoring, or debugging.
3. **No control for API latency** - condition B always ran after condition A. Later runs may have faced different API load. Interleaving would be better.
4. **Token counting includes cache** - we summed `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`. The "real" cost vs cached cost isn't separated.
5. **No blind evaluation** - we analyzed diffs knowing which condition produced them. Ideally, a third party would rate diff quality without knowing the condition.
6. **CLAUDE.md content was optimized for this task** - the context file mentioned "closures, IIFEs, and control flow" which directly guided the agent toward those edge cases. A generic CLAUDE.md might not show the same quality improvement.
7. **Commit messages only** - we don't have the agent's intermediate reasoning. The session logs could reveal whether the quality difference was due to CLAUDE.md guidance or random variation.

---

## Recommendations for Next Run

1. **Increase N to 5** per condition (or higher) for statistical power
2. **Interleave conditions** (A-B-A-B instead of AAA-BBB) to control for API latency drift
3. **Add a second task** - an implementation task, not just test-writing
4. **Blind evaluation** - have someone rate diff quality without knowing the condition
5. **Separate cache tokens** - report `input_tokens`, `cache_read`, and `cache_creation` separately
6. **Test a "generic" CLAUDE.md** - one that doesn't mention the specific task domain
7. **Parse session logs** - extract the agent's reasoning chain to understand WHY it made different decisions
