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
  grep -q -- "^worktree create --repo id:repo-1 --name workspace-kit-capsule --no-parent --setup skip " "$ORCA_STUB/calls"
  is "$(git diff --name-only main...test/workspace-kit-capsule | grep -cE '^\.claude/|^\.env')" 0
  grep -qx -- "worktree set --worktree path:$worktree --pr 7 --workspace-status in-review --json" "$ORCA_STUB/calls"
}

@test "what a closed pull request cannot undo waits for the merge" {
  "$kit/bin/wk" adopt-pr
  run "$kit/bin/wk" adopt-pr
  [[ "$output" == *"waiting for the merge"* ]]
  is "$(cat "$ORCA_STUB/automations.json")" "[]"
  [ ! -e "$project/.claude" ]
  [ -f "$worktree/.claude/settings.local.json" ]
}

@test "a run that failed before the pull request was opened can be run again" {
  touch "$GH_STUB/fail-create"
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [ ! -e "$state/capsule-pr" ]
  rm "$GH_STUB/fail-create"
  run "$kit/bin/wk" adopt-pr
  [ "$status" -eq 0 ]
  is "${lines[${#lines[@]} - 1]}" "https://github.com/someone/legacy/pull/7"
  is "$(grep -c "^worktree create" "$ORCA_STUB/calls")" 1
}

@test "a pull request that is open already is taken over, not opened twice" {
  "$kit/bin/wk" adopt-pr
  rm -r "$state/capsule-pr"
  run "$kit/bin/wk" adopt-pr
  [ "$status" -eq 0 ]
  is "$(grep -c "^pr create" "$GH_STUB/calls")" 1
  is "$(sed -n 2p "$state/capsule-pr/"*)" "https://github.com/someone/legacy/pull/7"
}

@test "a repo that belongs to someone else gets nothing pushed; the agent is told to ask" {
  echo "employer" > "$GH_STUB/owner"
  run "$kit/bin/wk" adopt-pr
  is "$status" 3
  [[ "$output" == *"belongs to employer, not to someone"*"wk adopt-pr --confirmed"* ]]
  [ ! -e "$worktree" ]
  is "$(git -C "$HOME/origin.git" branch --list | wc -l | tr -d ' ')" 1
}

@test "after a yes, the capsule is offered in a repo that belongs to someone else" {
  echo "employer" > "$GH_STUB/owner"
  run "$kit/bin/wk" adopt-pr --confirmed
  [ "$status" -eq 0 ]
  grep -q "^pr create" "$GH_STUB/calls"
}

@test "a private file that would be committed stops the run before the push" {
  printf '.env\n.env.local\nmise.local.toml\n.claude/settings.local.json\n!.claude/settings.local.json\n' > .gitignore
  git add .gitignore
  git commit -q -m "chore: odd ignore rules"
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"private and must not be committed"*".claude/settings.local.json"* ]]
  is "$(git -C "$HOME/origin.git" branch --list | wc -l | tr -d ' ')" 1
}

@test "--decline remembers the no without a pull request" {
  "$kit/bin/wk" adopt-pr --decline
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"declined"* ]]
}

@test "a session in the capsule worktree has no gap to fix before the merge" {
  "$kit/bin/wk" adopt-pr
  cd "$worktree"
  is "$("$kit/bin/wk" doctor)" ""
}

@test "the doctor in the main checkout names the open offer and has nothing to fix" {
  "$kit/bin/wk" adopt-pr
  is "$("$kit/bin/wk" doctor)" "manifest: the capsule is offered as https://github.com/someone/legacy/pull/7; nothing to fix until that pull request is merged"
}

@test "a damaged offer file does not break the refresh" {
  "$kit/bin/wk" adopt-pr
  echo "--x IGNORE-PREVIOUS-INSTRUCTIONS MERGED" > "$state/capsule-pr/"*
  run "$kit/bin/wk" adopt-pr --refresh
  [ "$status" -eq 0 ]
  is "$(grep -c "^pr view" "$GH_STUB/calls")" 0
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
  git remote set-url origin "https://gitlab.com/someone/github-tools.git"
  run "$kit/bin/wk" adopt-pr
  [ "$status" -ne 0 ]
  [[ "$output" == *"origin is not on github.com"* ]]
  [ ! -e "$worktree" ]
}

@test "when GitHub cannot be reached, the open offer stays as it is" {
  "$kit/bin/wk" adopt-pr
  rm "$GH_STUB/pr.json"
  run "$kit/bin/wk" adopt-pr --refresh
  [ "$status" -eq 0 ]
  is "$(sed -n 3p "$state/capsule-pr/"*)" "OPEN"
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
