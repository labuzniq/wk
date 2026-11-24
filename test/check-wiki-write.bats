#!/usr/bin/env bats
# The wiki rule hook: a file write under a vault's wiki/ is blocked unless the session is a wiki-ingest or wiki-lint run.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  project="$HOME/projects/demo"
  new_repo "$project"
  printf 'slug = "demo"\ntype = "code"\nvault = "knowledge-base"\n' > "$project/.workspace-kit.toml"
  mkdir -p "$project/knowledge-base/wiki" "$project/knowledge-base/raw/inbox" "$project/docs/wiki"
}

# agent_writes <tool> <file> [cwd] [session_id]: feed the hook what Claude Code sends before a file write.
agent_writes() {
  jq -n --arg tool "$1" --arg file "$2" --arg cwd "${3:-$project}" --arg id "${4-abc}" \
    '{session_id: $id, transcript_path: "/transcripts/\($id).jsonl", cwd: $cwd, permission_mode: "default", hook_event_name: "PreToolUse",
      tool_name: $tool, tool_use_id: "toolu_1",
      tool_input: (if $tool == "NotebookEdit" then {notebook_path: $file, new_source: "x"} else {file_path: $file, content: "x"} end)}' \
    | "$kit/hooks/check-wiki-write.sh"
}

blocked() {
  run agent_writes "$@"
  is "$status" 2
  [[ "$output" == "Blocked by the workspace kit: "* ]] || { echo "said: $output"; return 1; }
}

allowed() {
  run agent_writes "$@"
  is "$status:$output" "0:"
}

@test "a write to a wiki page is blocked and the message names the inbox" {
  blocked Write "$project/knowledge-base/wiki/learnings.md"
  [[ "$output" == *"$project/knowledge-base/wiki/learnings.md is a wiki page"* ]]
  [[ "$output" == *"write a dated note to $project/knowledge-base/raw/inbox/<date>-<title>.md"* ]]
  [[ "$output" == *'run the `wiki-ingest` or `wiki-lint` skill'* ]]
  [[ "$output" == *'Only if this session is running one of those two skills'*'never set it for other work.' ]]
}

@test "the message gives a wiki run that was not marked the command that marks it" {
  blocked Write "$project/knowledge-base/wiki/learnings.md"
  mark=$(sed -n 's/.*run `\(mkdir -p [^`]*\)`, then write again.*/\1/p' <<<"$output")
  is "$mark" "mkdir -p $state/sessions/no-capture && touch $state/sessions/no-capture/abc"
  eval "$mark"
  allowed Write "$project/knowledge-base/wiki/learnings.md"
}

@test "a session id that is not a file name lets the write pass and says so" {
  mkdir -p "$state/sessions/no-capture"
  run agent_writes Write "$project/knowledge-base/wiki/learnings.md" "$project" "../../../../.gitconfig"
  is "$status" 1
  [[ "$output" == "check-wiki-write: the session id "* ]]
}

@test "an empty session id lets the write pass and names the real problem" {
  run agent_writes Write "$project/knowledge-base/wiki/learnings.md" "$project" ""
  is "$status" 1
  [[ "$output" == "check-wiki-write: the hook input is not the JSON a file write sends"* ]]
}

@test "a vault written with a closing slash is covered" {
  printf 'slug = "demo"\ntype = "code"\nvault = "knowledge-base/"\n' > "$project/.workspace-kit.toml"
  blocked Write "$project/knowledge-base/wiki/learnings.md"
}

@test "edits, new pages in new folders and notebooks under wiki/ are blocked" {
  blocked Edit "$project/knowledge-base/wiki/overview.md"
  blocked MultiEdit "$project/knowledge-base/wiki/overview.md"
  blocked Write "$project/knowledge-base/wiki/howto/new/deploy.md"
  blocked NotebookEdit "$project/knowledge-base/wiki/concepts/numbers.ipynb"
  blocked Write "knowledge-base/wiki/learnings.md"
}

@test "a wiki-ingest or wiki-lint session may write the wiki" {
  mkdir -p "$state/sessions/no-capture"
  touch "$state/sessions/no-capture/wiki-run"
  allowed Write "$project/knowledge-base/wiki/learnings.md" "$project" wiki-run
  blocked Write "$project/knowledge-base/wiki/learnings.md" "$project" abc
}

@test "the rest of the vault, and other folders named wiki, stay writable" {
  allowed Write "$project/knowledge-base/raw/inbox/2026-11-23-note.md"
  allowed Write "$project/knowledge-base/index.md"
  allowed Write "$project/docs/wiki/page.md"
  allowed Write "$project/README.md"
}

@test "a project without a capsule is left alone" {
  plain="$HOME/projects/plain"
  new_repo "$plain"
  mkdir -p "$plain/knowledge-base/wiki"
  allowed Write "$plain/knowledge-base/wiki/page.md" "$plain"
  mkdir -p "$HOME/notes/wiki"
  allowed Write "$HOME/notes/wiki/page.md" "$HOME/notes"
}

@test "the wiki of the checkout and the wiki of the primary checkout are both covered in a worktree" {
  git -C "$project" add -A
  git -C "$project" commit -q -m "chore: add capsule"
  git -C "$project" worktree add -q "$HOME/projects/demo-fix" -b fix
  mkdir -p "$HOME/projects/demo-fix/knowledge-base/wiki"
  blocked Write "$HOME/projects/demo-fix/knowledge-base/wiki/learnings.md" "$HOME/projects/demo-fix"
  blocked Write "$project/knowledge-base/wiki/learnings.md" "$HOME/projects/demo-fix"
}

@test "a vault outside the repo is covered from the project's sessions" {
  mkdir -p "$HOME/vault/wiki"
  printf 'slug = "demo"\ntype = "code"\nvault = "%s"\n' "$HOME/vault" > "$project/.workspace-kit.toml"
  blocked Write "$HOME/vault/wiki/learnings.md"
  allowed Write "$HOME/vault/raw/inbox/note.md"
}

@test "input that is not JSON lets the write pass and says that nothing was checked" {
  run bash -c 'echo "/wiki/ but not JSON" | "$1"' _ "$kit/hooks/check-wiki-write.sh"
  is "$status" 1
  [[ "$output" == "check-wiki-write: the hook input is not the JSON a file write sends, so the wiki rule was not checked"* ]]
}

@test "input without a file path lets the write pass and says that nothing was checked" {
  run bash -c 'echo "{\"session_id\": \"abc\", \"cwd\": \"/x/wiki/y\"}" | "$1"' _ "$kit/hooks/check-wiki-write.sh"
  is "$status" 1
}

@test "the installed settings run the hook before file writes" {
  merged=$(echo '{}' | jq --arg kit /kit --argjson skills '[]' --slurpfile fragment "$kit/claude/settings.fragment.json" -f "$kit/claude/merge-settings.jq")
  is "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Write|Edit|MultiEdit|NotebookEdit") | .hooks[].command' <<<"$merged")" "/kit/hooks/check-wiki-write.sh"
}
