#!/usr/bin/env bash
# Claude Code calls this instead of `git worktree add`. The last stdout line must be the worktree path.
set -euo pipefail
input=$(cat)
name=$(jq -r '.name' <<<"$input")
repo_root=$(dirname "$(git -C "$(jq -r '.cwd' <<<"$input")" rev-parse --path-format=absolute --git-common-dir)")

repo_id=$(orca repo list --json | jq -r --arg path "$repo_root" '.result.repos[] | select(.path == $path) | .id')
[ -n "$repo_id" ] || repo_id=$(orca repo add --path "$repo_root" --json | jq -r '.result.repo.id')

cd "$repo_root"
orca worktree create --repo "id:$repo_id" --name "$name" --parent-worktree active --setup run --json | jq -er '.result.worktree.path'
