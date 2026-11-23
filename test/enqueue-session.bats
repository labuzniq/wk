#!/usr/bin/env bats
# The session queue hook: a finished session in a project with a capsule becomes one file in that project's queue.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  project="$HOME/projects/demo"
  new_repo "$project"
  printf 'slug = "demo"\ntype = "code"\nvault = "knowledge-base"\n' > "$project/.workspace-kit.toml"
  mkdir -p "$project/knowledge-base/wiki"
  git -C "$project" add .workspace-kit.toml
  git -C "$project" commit -q -m "chore: add capsule"
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
  is "$(queued)" 1
  entry=$(cat "$queue"/*-abc.json)
  is "$(jq -r '[.session_id, .transcript_path, .cwd, .repo_root, .project_slug, .branch, .orca_worktree_id, .event] | join(" ")' <<<"$entry")" \
    "abc /transcripts/abc.jsonl $project $project demo main repo-1::$project SessionEnd"
  [[ "$(jq -r .at <<<"$entry")" =~ ^20[0-9-]+T[0-9:]+Z$ ]]
}

@test "without ORCA_WORKTREE_ID the worktree id comes from the saved card" {
  mkdir -p "$state/cards"
  echo '{"result": {"worktree": {"id": "repo-1::saved"}}}' > "$(card_file "$project")"
  session_ends abc
  is "$(jq -r '.orca_worktree_id' "$queue"/*-abc.json)" "repo-1::saved"
}

@test "the same session ending twice is queued once" {
  session_ends abc
  session_ends abc
  is "$(queued)" 1
}

@test "an older queue entry of the same session is replaced" {
  mkdir -p "$queue"
  touch "$queue/2020-01-01-abc.json"
  session_ends abc
  is "$(queued)" 1
  [ ! -e "$queue/2020-01-01-abc.json" ]
}

@test "from a worktree, repo_root is the main checkout and the branch is the worktree's" {
  git -C "$project" worktree add -q "$HOME/task" -b task
  session_ends abc "$HOME/task"
  is "$(jq -r '[.cwd, .repo_root, .branch] | join(" ")' "$queue"/*-abc.json)" "$HOME/task $project task"
}

@test "two sessions are queued as two files" {
  session_ends abc
  session_ends def
  is "$(queued)" 2
}

@test "a project without a capsule queues nothing" {
  rm "$project/.workspace-kit.toml"
  session_ends abc
  is "$(queued)" 0
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
  is "$(queued)" 0
  session_ends def
  is "$(queued)" 1
}

@test "a session that ran inside the vault queues nothing" {
  session_ends abc "$project/knowledge-base/wiki"
  is "$(queued)" 0
  session_ends abc "$project"
  is "$(queued)" 1
}
