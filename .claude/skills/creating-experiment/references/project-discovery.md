# Project Discovery Procedure

Search GitHub for a repository and issue suitable for an AgentProbe experiment.

## Repository Criteria (all required)

1. **Has a test suite** — package.json with a `test` script, Makefile with a
   `test` target, or CI config running tests. No tests = no objective verification.

2. **Simple local setup** — `git clone` + one install command + it works.
   Exclude: Docker, external databases, API keys, multi-service setups.

3. **Active maintenance** — Last commit within 90 days.

4. **Sufficient complexity** — 1,000+ stars OR 50+ contributors.

5. **Permissive license** — MIT, Apache-2.0, BSD.

## Issue Criteria (all required)

6. **Labeled for contribution** — One of: `good first issue`, `help wanted`,
   `accepting prs`, `contributions welcome`, `up-for-grabs`.

7. **Not trivial** — Exclude titles with: "typo", "docs", "readme", "chore",
   "bump", "update dependency".

8. **Not architectural** — Exclude: "rewrite", "migration", "redesign",
   "major refactor". Must be completable in 50 agent turns.

9. **Recent** — Created within 180 days. Prefer post-training-cutoff issues.

10. **Unsolved** — No linked PRs, no "I'm working on this" comments.

11. **Has reproduction or spec** — Code example, error message, expected vs
    actual behavior, or clear feature spec. Reject vague issues.

## Search Commands

```bash
# Step 1: Repos by language and stars
gh search repos --language=typescript --stars=">1000" --sort=updated --limit=20

# Step 2: Issues per repo
gh search issues --repo=OWNER/REPO \
  --label="good first issue,help wanted" \
  --state=open --sort=created --limit=10

# Step 3: Check for linked PRs
gh api repos/OWNER/REPO/issues/NUMBER/timeline | jq '[.[] | select(.event=="cross-referenced")]'
```

Adapt the `--language` filter to match the hypothesis domain.

## Presentation Format

Present 3-5 candidates:
- Repository: name, stars, description
- Issue: title, number, date, labels
- Fit: why it matches (test suite, setup simplicity, issue clarity)
- Concerns: anything that could complicate the experiment

Let the user choose or reject all and search again.

## Post-Selection

1. Clone to `~/work/<repo-name>/`
2. Run setup (e.g., `pnpm install`)
3. Run tests to verify they pass at HEAD
4. Record HEAD as `base_commit`
5. Compose `task-prompt.txt` from issue text (imperative, no hints)
6. Infer `test_command` and `typecheck_command` from project config
