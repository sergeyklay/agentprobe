#!/usr/bin/env bash
# Setup for "with CLAUDE.md" condition (treatment)
# Args: $1 = worktree directory
set -euo pipefail
WORKTREE_DIR="${1:?Usage: setup.sh <worktree_dir>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/artifacts/CLAUDE.md" "$WORKTREE_DIR/CLAUDE.md"
echo "  [setup] CLAUDE.md placed in worktree root"
