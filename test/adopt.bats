#!/usr/bin/env bats
# `wk adopt` and `wk doctor` against a scratch project.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  project="$HOME/projects/demo"
  mkdir -p "$project"
  cd "$project" || return 1
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
  is "$(head -1 docs/agents/issue-tracker.md)" "# stand-in issue-tracker-local"
  grep -qx 'slug = "demo"' .workspace-kit.toml
  is "$(cat "$state/repos/$(printf '%s' "$project" | shasum | cut -d' ' -f1)")" 'orca_repo_id = "repo-1"'
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json" | sort | paste -sd, -)" "Wiki ingest: demo,Wiki lint: demo,Worktree cleanup: demo"
  grep "^automations create --name Wiki ingest: demo " "$ORCA_STUB/calls" | grep -q -- "--extra-agent-args=--model sonnet"
  grep "^automations create --name Wiki lint: demo " "$ORCA_STUB/calls" | grep -q -- "--extra-agent-args=--model sonnet"
  grep "^automations create --name Worktree cleanup: demo " "$ORCA_STUB/calls" | grep -q -- "--extra-agent-args=--model haiku"
}

@test "a second run changes nothing" {
  "$kit/libexec/wk-adopt"
  before=$(snapshot)
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  is "$(snapshot)" "$before"
  [[ "$output" != *created* ]]
}

@test "after adopt the doctor prints no fixable gap" {
  "$kit/libexec/wk-adopt"
  run "$kit/bin/wk" doctor
  [ "$status" -eq 0 ]
  is "$output" "vision: deferred until 20 commits (now 1); the newest spec is the guidance until then. Nothing to fix."
  run "$kit/bin/wk" doctor
  is "$output" ""
}

@test "files that are already there are kept" {
  new_repo .
  echo "# Demo, in the owner's words" > CLAUDE.md
  printf '[tasks.setup]\nrun = "make"\n' > mise.toml
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  is "$(head -1 CLAUDE.md)" "# Demo, in the owner's words"
  is "$(cat mise.toml)" $'[tasks.setup]\nrun = "make"'
  [[ "$output" == *"kept    mise.toml"* ]]
}

@test "the stack is detected from the repo" {
  echo '{"scripts": {"lint": "eslint ."}}' > package.json
  echo '{}' > package-lock.json
  "$kit/libexec/wk-adopt"
  grep -qx 'stack = \["ts"\]' .workspace-kit.toml
  grep -qx 'run = \["npm install"\]' mise.toml
}

@test "a GitHub remote picks the GitHub tracker doc and origin as the base" {
  new_repo .
  git remote add origin git@github.com:someone/demo.git
  "$kit/libexec/wk-adopt"
  is "$(head -1 docs/agents/issue-tracker.md)" "# stand-in issue-tracker-github"
  grep -qx -- "repo set-base-ref --repo id:repo-1 --ref origin/main --json" "$ORCA_STUB/calls"
}

@test "a Python project gets the starter checks, wired into its lint task, and the run names them" {
  echo '[project]' > pyproject.toml
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  [ -f checks/starter/python.toml ] && [ -f checks/starter/python.txt ] && [ -f checks/README.md ]
  [[ "$output" == *"created checks/starter/python.toml"* ]]
  [[ "$output" == *"added starter checks for python: E722, BLE001, S110, T201, PGH003, PGH004"* ]]
  is "$(grep -A1 '^\[tasks.lint\]' mise.toml | grep -c 'ruff check --config checks/starter/python.toml || { cat checks/starter/python.txt; exit 1; }')" 1
  # first in the list: mise stops at the first command that fails, and the project's own linter may not be installed yet
  grep -q '^run = \["mise x ruff@.*", "uv run ruff check"\]$' mise.toml
  [[ "$output" != *"does not run the starter checks"* ]]
}

@test "a TypeScript project gets the starter checks in its lint task" {
  echo '{}' > package.json
  run "$kit/libexec/wk-adopt"
  [[ "$output" == *"added starter checks for ts: noExplicitAny, "* ]]
  is "$(grep -A1 '^\[tasks.lint\]' mise.toml | grep -c 'biome lint --config-path=checks/starter/ts.json || { cat checks/starter/ts.txt; exit 1; }')" 1
}

@test "a Swift project without a package file gets a lint task with the starter checks" {
  new_repo .
  mkdir App.xcodeproj
  touch App.xcodeproj/project.pbxproj
  git add App.xcodeproj
  run "$kit/libexec/wk-adopt"
  [[ "$output" == *"added starter checks for swift: force_unwrapping, "* ]]
  is "$(grep -A1 '^\[tasks.lint\]' mise.toml | grep -c 'swiftlint lint --strict --quiet --config checks/starter/swift.yml || { cat checks/starter/swift.txt; exit 1; }')" 1
}

@test "a project gets starter checks for its own stacks only" {
  echo '[project]' > pyproject.toml
  "$kit/libexec/wk-adopt"
  is "$(cd checks/starter && echo *)" "python.toml python.txt"
}

@test "a folder with no stack gets no checks folder" {
  run "$kit/libexec/wk-adopt"
  [ ! -e checks ]
  [[ "$output" != *"starter checks"* ]]
}

@test "an existing lint config and a changed starter file are kept" {
  printf '[project]\n\n[tool.ruff.lint]\nselect = ["F"]\n' > pyproject.toml
  mkdir -p checks/starter
  echo '# the owner removed every rule' > checks/starter/python.toml
  before=$(shasum pyproject.toml checks/starter/python.toml)
  run "$kit/libexec/wk-adopt"
  is "$(shasum pyproject.toml checks/starter/python.toml)" "$before"
  [[ "$output" == *"kept    checks/starter/python.toml"* ]]
  [[ "$output" == *"created checks/starter/python.txt"* ]]
}

@test "a kept mise.toml is not changed; the run prints the command to add to its lint task" {
  echo '[project]' > pyproject.toml
  printf '[tasks.setup]\nrun = "uv sync"\n\n[tasks.lint]\nrun = ["uv run ruff check"]\n' > mise.toml
  before=$(cat mise.toml)
  run "$kit/libexec/wk-adopt"
  is "$(cat mise.toml)" "$before"
  [ -f checks/starter/python.toml ]
  [[ "$output" == *"kept    mise.toml: its lint task does not run the starter checks for python; add this command to the run list of [tasks.lint]: mise x ruff@"*" -- ruff check --config checks/starter/python.toml || { cat checks/starter/python.txt; exit 1; }"* ]]
}

@test "every starter check with a message is switched on in its config" {
  for messages in "$kit"/templates/checks/starter/*.txt; do
    ids=$(sed -n 's/^  \([^ ]*\) .*/\1/p' "$messages")
    [ -n "$ids" ] || { echo "no check in $messages"; return 1; }
    for id in $ids; do
      for config in "${messages%.txt}".*; do [ "$config" = "$messages" ] || cat "$config"; done | grep -q -- "$id" || { echo "$id has a message in $messages but is in no config"; return 1; }
    done
  done
}

@test "a stack the kept manifest names and a stack found later both get starter checks" {
  "$kit/libexec/wk-adopt"
  sed -i '' 's/^stack = .*/stack = ["swift"]/' .workspace-kit.toml
  echo '[project]' > pyproject.toml
  run "$kit/libexec/wk-adopt"
  is "$(cd checks/starter && echo *)" "python.toml python.txt swift.txt swift.yml"
}
