#!/usr/bin/env bats
# The session-start hook: what a new session is told about the capsule.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() { setup_home; }

# session_starts [cwd]: feed the hook what Claude Code sends on SessionStart; the folder defaults to the current one.
session_starts() { jq -n --arg cwd "${1:-$PWD}" '{cwd: $cwd, source: "startup"}' | "$kit/hooks/session-start.sh"; }

@test "a new folder under the projects folder is set up at once" {
  mkdir "$HOME/projects/fresh"
  run session_starts "$HOME/projects/fresh"
  [[ "$output" == "New project folder without a workspace-kit capsule. Before anything else, run \`wk adopt\`"* ]]
}

@test "an empty repo is set up at once" {
  git init -q "$HOME/projects/fresh"
  run session_starts "$HOME/projects/fresh"
  [[ "$output" == "New repo without a workspace-kit capsule. Before anything else, run \`wk adopt\`"* ]]
}

@test "an existing repo on GitHub gets the capsule as a pull request, without a question" {
  existing_repo
  run session_starts
  [[ "$output" == *"run \`wk adopt-pr\`"* ]]
  [[ "$output" != *"Ask the user"* ]]
}

@test "an existing repo with no GitHub remote is asked about once" {
  existing_repo
  git remote remove origin
  run session_starts
  [[ "$output" == *"Ask the user once, yes or no"* ]]
  [[ "$output" != *"adopt-pr"* ]]
}

@test "a no remembered before pull requests were used is still honoured" {
  existing_repo
  mkdir -p "$state/declined"
  touch "$state/declined/$(printf '%s' "$project" | shasum | cut -d' ' -f1)"
  run session_starts
  is "$output" ""
}

@test "while the capsule pull request is open, nothing is said" {
  existing_repo
  "$kit/bin/wk" adopt-pr
  run session_starts
  is "$output" ""
}

@test "a merged capsule pull request that this checkout lacks leads to a pull, not to a second offer" {
  existing_repo
  "$kit/bin/wk" adopt-pr
  echo '{"state": "MERGED"}' > "$GH_STUB/pr.json"
  "$kit/bin/wk" adopt-pr --refresh
  run session_starts
  [[ "$output" == *"pull/7 is merged"*"git pull --ff-only"* ]]
  [[ "$output" != *"adopt-pr"* ]]
}

@test "a closed capsule pull request means the repo is never offered the capsule again" {
  existing_repo
  "$kit/bin/wk" adopt-pr
  echo '{"state": "CLOSED"}' > "$GH_STUB/pr.json"
  "$kit/bin/wk" adopt-pr --refresh
  run session_starts
  is "$output" ""
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"declined"* ]]
}

@test "a project with a capsule gets its context" {
  adopted_project
  run session_starts
  [[ "$output" == "Project: demo (code)"* ]]
}
