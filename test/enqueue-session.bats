#!/usr/bin/env bats
# The session queue hook: a finished session in a project with a capsule becomes one file in that project's queue.

load helpers

setup() {
  setup_home
  project="$HOME/projects/demo"
  new_repo "$project"
  printf 'slug = "demo"\ntype = "code"\nvault = "knowledge-base"\n' > "$project/.workspace-kit.toml"
  mkdir -p "$project/knowledge-base/wiki"
  queue="$state/sessions/demo/queue"
}

# session_ends <session_id> [cwd]: feed the hook what Claude Code sends on SessionEnd.
session_ends() {
  jq -n --arg id "$1" --arg cwd "${2:-$project}" \
    '{session_id: $id, transcript_path: "/transcripts/\($id).jsonl", cwd: $cwd, hook_event_name: "SessionEnd", reason: "exit"}' \
    | "$kit/hooks/enqueue-session.sh"
}

queued() { find "$queue" -type f 2>/dev/null | wc -l | tr -d ' '; }

@test "a finished session is queued with what ingest needs" {
  export ORCA_WORKTREE_ID="repo-1::$project"
  session_ends abc
  [ "$(queued)" -eq 1 ]
  entry=$(cat "$queue"/*-abc.json)
  [ "$(jq -r '[.session_id, .transcript_path, .cwd, .repo_root, .project_slug, .branch, .orca_worktree_id, .event] | join(" ")' <<<"$entry")" \
    = "abc /transcripts/abc.jsonl $project $project demo main repo-1::$project SessionEnd" ]
}

@test "without ORCA_WORKTREE_ID the worktree id comes from the saved card" {
  mkdir -p "$state/cards"
  echo '{"result": {"worktree": {"id": "repo-1::saved"}}}' > "$state/cards/$(printf '%s' "$project" | shasum | cut -d' ' -f1).json"
  session_ends abc
  [ "$(jq -r '.orca_worktree_id' "$queue"/*-abc.json)" = "repo-1::saved" ]
}

@test "the same session ending twice is queued once" {
  session_ends abc
  session_ends abc
  [ "$(queued)" -eq 1 ]
}

@test "two sessions are queued as two files" {
  session_ends abc
  session_ends def
  [ "$(queued)" -eq 2 ]
}

@test "a project without a capsule queues nothing" {
  rm "$project/.workspace-kit.toml"
  session_ends abc
  [ "$(queued)" -eq 0 ]
}

@test "a folder outside any git repo queues nothing" {
  run session_ends abc "$HOME"
  [ "$status" -eq 0 ]
  [ ! -d "$state/sessions" ]
}

@test "a session marked no-capture queues nothing" {
  mkdir -p "$state/sessions/no-capture"
  touch "$state/sessions/no-capture/abc"
  session_ends abc
  [ "$(queued)" -eq 0 ]
}

@test "a session that ran inside the vault queues nothing" {
  session_ends abc "$project/knowledge-base/wiki"
  [ "$(queued)" -eq 0 ]
}
