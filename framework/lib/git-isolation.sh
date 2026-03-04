#!/usr/bin/env bash
# git-isolation.sh - Git worktree based isolation for experiment runs
#
# Provides: create_worktree, cleanup_worktree, cleanup_all_worktrees
#
# Each run gets a completely isolated worktree. The main repo is never touched.
# This replaces the old approach of git reset --hard + git clean -fd.

WORKTREE_BASE="/tmp/agentprobe-runs"

# Create an isolated worktree detached at a specific commit.
# Prints the worktree path to stdout.
# Usage: worktree_dir=$(create_worktree "/path/to/repo" "commit_sha" "label")
create_worktree() {
  local repo_dir="$1"
  local base_commit="$2"
  local label="$3"
  local worktree_dir="${WORKTREE_BASE}/${label}-$(date +%s)"

  mkdir -p "$(dirname "$worktree_dir")"

  if ! (cd "$repo_dir" && git worktree add "$worktree_dir" --detach "$base_commit") >&2 2>&1; then
    echo "ERROR: Failed to create worktree at $worktree_dir" >&2
    return 1
  fi

  # Configure git for anonymous commits (no gpg)
  (
    cd "$worktree_dir"
    git config user.email "experiment@agentprobe.local"
    git config user.name "AgentProbe Runner"
    git config commit.gpgsign false
  ) >&2 2>&1

  echo "$worktree_dir"
}

# Remove a worktree and prune stale entries.
# Usage: cleanup_worktree "/path/to/repo" "/path/to/worktree"
cleanup_worktree() {
  local repo_dir="$1"
  local worktree_dir="$2"

  [[ -d "$worktree_dir" ]] || return 0

  (cd "$repo_dir" && git worktree remove "$worktree_dir" --force 2>/dev/null) || {
    rm -rf "$worktree_dir"
    (cd "$repo_dir" && git worktree prune 2>/dev/null)
  }
}

# Remove all worktrees created by agentprobe.
# Usage: cleanup_all_worktrees "/path/to/repo"
cleanup_all_worktrees() {
  local repo_dir="$1"
  if [[ -d "$WORKTREE_BASE" ]]; then
    for wt in "$WORKTREE_BASE"/*/; do
      [[ -d "$wt" ]] && cleanup_worktree "$repo_dir" "$wt"
    done
    rmdir "$WORKTREE_BASE" 2>/dev/null || true
  fi
}
