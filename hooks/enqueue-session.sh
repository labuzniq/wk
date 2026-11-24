#!/usr/bin/env bash
# Queues the session for wiki-ingest. SessionEnd allows 1.5 seconds, so this only writes one file.
kit="$(dirname "$0")/.."
input=$(cat)
session_id=$(jq -r '.session_id' <<<"$input")
[ -n "$(jq -r '.transcript_path // empty' <<<"$input")" ] || exit 0 # a Codex ephemeral session keeps no transcript
cd "$(jq -r '.cwd' <<<"$input")" 2>/dev/null || exit 0
# shellcheck source=../lib/project.sh
. "$kit/lib/project.sh" || exit 0
[ -f "$manifest" ] || exit 0
[ ! -f "$state_dir/sessions/no-capture/$session_id" ] || exit 0
case "$PWD/" in "$(vault_dir)"/*) exit 0 ;; esac

queue="$state_dir/sessions/$(manifest_value slug)/queue"
mkdir -p "$queue"
rm -f "$queue"/*-"$session_id".json
worktree_id="${ORCA_WORKTREE_ID:-$(jq -r '.result.worktree.id' "$state_dir/cards/$(path_key "$root").json" 2>/dev/null)}"
jq -n --argjson input "$input" --arg repo_root "$primary" --arg slug "$(manifest_value slug)" \
  --arg branch "$(git branch --show-current)" --arg worktree_id "$worktree_id" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $input.session_id, transcript_path: $input.transcript_path, cwd: $input.cwd, repo_root: $repo_root,
    project_slug: $slug, branch: $branch, orca_worktree_id: $worktree_id, at: $at, event: $input.hook_event_name}' \
  > "$queue/$(date +%Y-%m-%d)-$session_id.json"
exit 0
