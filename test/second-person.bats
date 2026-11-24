#!/usr/bin/env bats
# A second person clones an adopted repo: nothing committed is theirs alone, and their first session sets up the rest.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  adopted_project
}

# second_person: the same repo as a fresh clone on a Mac whose Orca and kit state know nothing about it.
second_person() {
  git clone -q "$project" "$HOME/projects/clone"
  rm -r "$state"
  echo '[{"id": "another-repo", "path": "/somewhere/else"}]' > "$ORCA_STUB/repos.json"
  echo '[]' > "$ORCA_STUB/automations.json"
  cd "$HOME/projects/clone" || return 1
}

session_start() { jq -n --arg cwd "$PWD" '{cwd: $cwd}' | "$kit/hooks/session-start.sh"; }

@test "nothing the capsule commits holds a value of one person" {
  is "$(git grep -c '^slug = "demo"$')" ".workspace-kit.toml:1"
  run git grep -n -e repo-1 -e "$HOME" -e orca_repo_id
  is "$output" ""
}

@test "the first session of a second person names the gap and tells the agent to fix it without asking" {
  second_person
  run session_start
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project: demo (code)"* ]]
  [[ "$output" == *'orca_repo: this repo is not set up in your Orca on this Mac; run `wk adopt`'* ]]
  [[ "$output" == *"fix every gap yourself now, without asking"* ]]
}

@test "wk adopt sets up the second person and changes no committed file" {
  second_person
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  is "$(git status --porcelain)" ""
  is "$(cat "$state/repos/$(printf '%s' "$PWD" | shasum | cut -d' ' -f1)")" 'orca_repo_id = "repo-2"'
  is "$(jq -r '.permissions.additionalDirectories[0]' .claude/settings.local.json)" "$PWD/knowledge-base"
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json" | sort | paste -sd, -)" "Wiki ingest: demo,Wiki lint: demo"
  "$kit/bin/wk" doctor > /dev/null # the deferred vision is reported once per person
  run "$kit/bin/wk" doctor
  is "$output" ""
}

# A capsule from before the split: the manifest and the tracker doc name the first person's Orca repo id.
old_capsule() {
  { echo 'orca_repo_id = "repo-1"'; cat .workspace-kit.toml; } > manifest.new
  mv manifest.new .workspace-kit.toml
  sed -i '' -e 's/ Name the repo by the path of its primary checkout, the first line of `git worktree list`\./ The repo id is `orca_repo_id` in `.workspace-kit.toml`./' \
    -e 's/--repo path:<primary checkout> /--repo id:<repoId> /' docs/agents/issue-tracker.md
  grep -q 'id:<repoId>' docs/agents/issue-tracker.md
  git commit -qam "chore: capsule of the old kind"
}

@test "a capsule from before the split keeps working, and wk adopt takes the one-person value out" {
  old_capsule
  is "$("$kit/bin/wk" doctor | grep -v '^vision:' | cut -d: -f1)" "shared_values"
  git worktree add -q "$HOME/projects/ticket" -b ticket
  is "$(cd "$HOME/projects/ticket" && "$kit/bin/wk" doctor | grep -v '^vision:')" ""

  second_person
  run "$kit/bin/wk" doctor
  is "$(grep -v '^vision:' <<<"$output" | cut -d: -f1 | paste -sd' ' -)" "orca_repo shared_values automations"
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed orca_repo_id from .workspace-kit.toml"* ]]
  [[ "$output" == *"updated docs/agents/issue-tracker.md"* ]]
  is "$(git status --porcelain)" $' M .workspace-kit.toml\n M docs/agents/issue-tracker.md'
  is "$(git diff -U0 | grep -c '^[-+][^-+]')" 5
  is "$(grep -rl -e orca_repo_id -e repoId .workspace-kit.toml docs)" ""
  is "$("$kit/bin/wk" doctor | grep -v '^vision:')" ""
}

@test "in a worktree wk adopt sets up the person and leaves the old capsule to the primary checkout" {
  old_capsule
  rm -r "$state"
  git worktree add -q "$HOME/projects/ticket" -b ticket
  cd "$HOME/projects/ticket" || return 1
  is "$("$kit/bin/wk" doctor | grep -v '^vision:' | cut -d: -f1 | paste -sd' ' -)" "orca_repo automations"
  run "$kit/libexec/wk-adopt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept    orca_repo_id in this worktree's .workspace-kit.toml"* ]]
  is "$(git status --porcelain)" ""
  is "$("$kit/bin/wk" doctor | grep -v '^vision:')" ""
}

@test "wk adopt prints what it changes in Orca" {
  second_person
  run "$kit/libexec/wk-adopt"
  [[ "$output" == *"added   $PWD to Orca"* ]]
  [[ "$output" == *"set     the Orca base ref to origin/main"* ]]
}
