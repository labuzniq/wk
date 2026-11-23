#!/usr/bin/env bash
# Removes a Claude Code worktree through Orca only when it holds no work.
set -euo pipefail
path=$(jq -r '.worktree_path')
card=$(orca worktree show --worktree "path:$path" --json | jq -c '.result.worktree')
id=$(jq -r '.id' <<<"$card")
base=$(jq -r '.baseRef' <<<"$card")

if [ -z "$(git -C "$path" status --porcelain)" ] && [ "$(git -C "$path" rev-list --count "$base..HEAD")" -eq 0 ]; then
  orca worktree rm --worktree "id:$id" --delete-branch --json >/dev/null
else
  orca worktree set --worktree "id:$id" --comment "left by Claude Code, has changes" --json >/dev/null
fi
