#!/usr/bin/env bats
# `wk adopt-pr`: an existing repo gets its capsule on a branch, as a pull request. Nothing lands on the default branch.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  existing_repo
  worktree="$HOME/worktrees/workspace-kit-capsule"
}

@test "the capsule is committed on a branch, pushed, and offered as a pull request" {
  before=$(git rev-parse main)
  run "$kit/bin/wk" adopt-pr
  [ "$status" -eq 0 ]
  is "${lines[${#lines[@]} - 1]}" "https://github.com/someone/legacy/pull/7"
  is "$(git rev-parse main) $(git status --porcelain)" "$before "
  git -C "$HOME/origin.git" cat-file -e test/workspace-kit-capsule:.workspace-kit.toml
  is "$(git -C "$HOME/origin.git" rev-parse main)" "$before"
  grep -q "^pr create --title chore: add workspace-kit capsule" "$GH_STUB/calls"
  grep -qx -- "worktree set --worktree path:$worktree --pr 7 --workspace-status in-review --json" "$ORCA_STUB/calls"
}

@test "what a closed pull request cannot undo waits for the merge" {
  "$kit/bin/wk" adopt-pr
  is "$(cat "$ORCA_STUB/automations.json")" "[]"
  [ ! -e "$project/.claude" ]
}

@test "a second run opens no second pull request and names the first" {
  "$kit/bin/wk" adopt-pr
  run "$kit/bin/wk" adopt-pr
  [ "$status" -eq 0 ]
  [[ "$output" == *"already offered"*"pull/7"* ]]
  is "$(grep -c "^pr create" "$GH_STUB/calls")" 1
}

@test "a repo that already has a capsule is refused" {
  "$kit/libexec/wk-adopt" > /dev/null
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"already has a capsule"* ]]
}

@test "without a GitHub remote there is no pull request and nothing is created" {
  git remote set-url origin "$HOME/origin.git"
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"origin is not on GitHub"* ]]
  [ ! -e "$worktree" ]
}

@test "when GitHub cannot be reached, the open offer stays as it is" {
  "$kit/bin/wk" adopt-pr
  rm "$GH_STUB/pr.json"
  run "$kit/bin/wk" adopt-pr --refresh
  [ "$status" -eq 0 ]
  is "$(cut -d' ' -f3 "$state/capsule-pr/"*)" "OPEN"
  [ ! -e "$state/declined" ]
}

@test "after the merge, wk adopt in the main checkout creates the automations and the doctor gap goes away" {
  "$kit/bin/wk" adopt-pr
  git merge -q --no-ff -m "merge capsule" test/workspace-kit-capsule
  [[ "$("$kit/bin/wk" doctor)" == *"automations: the wiki automations are not created yet"* ]]
  "$kit/libexec/wk-adopt" > /dev/null
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json" | sort | paste -sd, -)" "Wiki ingest: legacy,Wiki lint: legacy"
  [[ "$("$kit/bin/wk" doctor)" != *"automations"* ]]
}
