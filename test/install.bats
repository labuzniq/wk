#!/usr/bin/env bats
# `install.sh` in a throwaway home: the scheduled pin update is created in Orca, once.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  echo '{}' > "$HOME/.claude/settings.json"
  : > "$HOME/kit/skills.txt"
  new_repo "$HOME/upstream"
  mkdir "$HOME/upstream/agents"
  printf -- '---\nname: reviewer\n---\nReview the code.\n' > "$HOME/upstream/agents/reviewer.md"
  git -C "$HOME/upstream" add -A
  git -C "$HOME/upstream" commit -q -m "feat: reviewer"
  printf '[source]\nrepo = "%s"\ncommit = "%s"\n\n[agents]\nreviewer = { skills = [] }\n' \
    "$HOME/upstream" "$(git -C "$HOME/upstream" rev-parse HEAD)" > "$HOME/kit/agents/agents.toml"
}

@test "the installer creates the weekly pin update automation in the kit's own workspace" {
  run "$kit/install.sh"
  [ "$status" -eq 0 ]
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json")" "Pin update"
  [[ "$output" == *"created automation 'Pin update'"* ]]
  created=$(grep "^automations create" "$ORCA_STUB/calls")
  [[ "$created" == *"--trigger weekly --day 1 --time 08:00"* ]]
  [[ "$created" == *'Run `wk pins-update`.'* ]]
  [[ "$created" == *"--provider claude --workspace path:$kit --fresh-session --enabled"* ]]
  is "$(jq -r '.[].path' "$ORCA_STUB/repos.json")" "$kit"
}

@test "a second install creates no second automation" {
  "$kit/install.sh"
  run "$kit/install.sh"
  [ "$status" -eq 0 ]
  is "$(jq length "$ORCA_STUB/automations.json")" 1
  is "$(jq length "$ORCA_STUB/repos.json")" 1
  [[ "$output" != *"created automation"* ]]
}

@test "an automation that is already in Orca is kept and named" {
  echo '[{"name": "Pin update"}]' > "$ORCA_STUB/automations.json"
  run "$kit/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept automation 'Pin update'"* ]]
  is "$(jq length "$ORCA_STUB/automations.json")" 1
}

@test "an automation the owner removed is not created again" {
  "$kit/install.sh"
  echo '[]' > "$ORCA_STUB/automations.json"
  run "$kit/install.sh"
  [ "$status" -eq 0 ]
  is "$(jq length "$ORCA_STUB/automations.json")" 0
  [[ "$output" == *"kept automation 'Pin update' (created before; delete $HOME/.local/state/workspace-kit/pin-update-automation"* ]]
}

@test "when Orca does not answer, the install goes on and says the automation is not created" {
  touch "$ORCA_STUB/down"
  run "$kit/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orca gave no list of automations, so 'Pin update' is not created; start Orca and run install.sh again"* ]]
  [ -L "$HOME/.local/bin/wk" ]
  [ ! -e "$HOME/.local/state/workspace-kit/pin-update-automation" ]
}
