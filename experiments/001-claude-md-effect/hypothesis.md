# Hypothesis: CLAUDE.md Effect on Agent Performance

## Claim

A well-crafted, hand-curated CLAUDE.md file containing only non-discoverable
information (build commands, architectural gotchas, boundaries) improves agent
task quality when working on a real codebase.

## Counter-claim

The ETH Zurich study (Gloaguen et al., arXiv:2602.11988) found that
LLM-generated context files decrease performance by ~2% and increase inference
cost by 20%+. Developer-written files showed an unstable +4%.

## Key difference from ETH Zurich

This experiment tests a **hand-curated** file written per vendor guidelines
(Anthropic, OpenAI, Addy Osmani), containing only landmines and conventions
the agent cannot discover from the codebase itself. The ETH Zurich study tested
(a) auto-generated files and (b) random developer-committed files of unknown quality.

## Metrics

- Tests pass/fail (binary)
- Duration (ms)
- Token usage (input, output, cache)
- Tool calls count
- Typecheck pass/fail
- Diff quality (qualitative)

## Prior results (v0, N=2)

See `archive/v0-claude-md-effect/report.md` and `archive/v0-claude-md-effect/analysis.md`.
Both conditions achieved 100% test success. CLAUDE.md condition was 155% slower
and used 58% more tokens, but produced deeper edge-case coverage in diffs.

## Design document

Full pre-registration with literature review, project selection rationale,
methodology, and AGENTS.md template: [`research/001-claude-md-effect-design.md`](../../research/001-claude-md-effect-design.md)
