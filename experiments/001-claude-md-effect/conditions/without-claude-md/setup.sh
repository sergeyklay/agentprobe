#!/usr/bin/env bash
# Setup for "without CLAUDE.md" condition (control)
# Args: $1 = worktree directory
set -euo pipefail
WORKTREE_DIR="${1:?Usage: setup.sh <worktree_dir>}"
rm -f "$WORKTREE_DIR/CLAUDE.md"
echo "  [setup] Control condition: no CLAUDE.md"
