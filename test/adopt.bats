#!/usr/bin/env bats
# `wk adopt` and `wk doctor` against a scratch project.

load helpers

setup() {
  setup_home
  project="$HOME/projects/demo"
  mkdir -p "$project"
  cd "$project"
}

# Every file of the project outside .git, with its checksum, plus what Orca was asked to keep.
snapshot() {
  find . -path ./.git -prune -o -type f -exec shasum {} + | sort
  cat "$ORCA_STUB/repos.json" "$ORCA_STUB/automations.json"
}

@test "the first run creates the capsule in a plain folder" {
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  for file in .workspace-kit.toml mise.toml orca.yaml .worktreeinclude CLAUDE.md docs/agents/issue-tracker.md \
    knowledge-base/wiki/overview.md .claude/settings.local.json; do
    [ -f "$file" ] || { echo "missing: $file"; return 1; }
  done
  [[ "$output" == *"created .workspace-kit.toml"* ]]
  [ "$(jq -r '.[].name' "$ORCA_STUB/automations.json" | sort | paste -sd, -)" = "Wiki ingest: demo,Wiki lint: demo" ]
}

@test "a second run changes nothing" {
  "$kit/libexec/wk-adopt"
  before=$(snapshot)
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  [ "$(snapshot)" = "$before" ]
  [[ "$output" != *created* ]]
}

@test "after adopt the doctor prints no fixable gap" {
  "$kit/libexec/wk-adopt"
  run "$kit/bin/wk" doctor
  [ "$status" -eq 0 ]
  [ "$output" = "vision: deferred until 20 commits (now 1); the newest spec is the guidance until then. Nothing to fix." ]
  run "$kit/bin/wk" doctor
  [ "$output" = "" ]
}

@test "files that are already there are kept" {
  new_repo .
  echo "# Demo, in the owner's words" > CLAUDE.md
  printf '[tasks.setup]\nrun = "make"\n' > mise.toml
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  [ "$(head -1 CLAUDE.md)" = "# Demo, in the owner's words" ]
  [ "$(cat mise.toml)" = $'[tasks.setup]\nrun = "make"' ]
  [[ "$output" == *"kept    mise.toml"* ]]
}

@test "the stack is detected from the repo" {
  echo '{"scripts": {"lint": "eslint ."}}' > package.json
  echo '{}' > package-lock.json
  "$kit/libexec/wk-adopt"
  grep -qx 'stack = \["ts"\]' .workspace-kit.toml
  grep -qx 'run = \["npm install"\]' mise.toml
}
