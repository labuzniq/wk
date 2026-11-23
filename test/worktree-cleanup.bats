#!/usr/bin/env bats
# Cleanup rule: `wk worktree-cleanup` removes a worktree only when its branch is merged and its card has been completed for 14 days.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  repo="$HOME/projects/demo"
  new_repo "$repo"
  tree="$HOME/worktrees/task"
  git -C "$repo" worktree add -q -b task "$tree"
  cd "$repo" || return 1
}

# cards <status> [base ref]: what Orca lists for the repo: the main checkout and the worktree in $tree.
cards() {
  jq -n --arg repo "$repo" --arg tree "$tree" --arg status "$1" --arg base "${2:-main}" \
    '{result: {truncated: false, worktrees: [
      {id: "card-0", instanceId: "inst-0", path: $repo, branch: "refs/heads/main", workspaceStatus: "completed", isMainWorktree: true, displayName: "main"},
      {id: "card-1", instanceId: "inst-1", path: $tree, branch: "refs/heads/task", baseRef: $base, workspaceStatus: $status, isMainWorktree: false, displayName: "task"}
    ]}}' > "$ORCA_STUB/list.json"
}

commit() { git -C "$tree" commit -q --allow-empty -m "feat: work"; }
merge() { git -C "$repo" merge -q --no-ff -m "merge task" task; }
# completed_days_ago <days> [instance id]: the card was first seen completed that long ago.
completed_days_ago() {
  local dir
  dir="$state/completed/$(printf '%s' "$repo" | shasum | cut -d' ' -f1)"
  mkdir -p "$dir"
  echo $(( $(date +%s) - $1 * 86400 )) > "$dir/$(printf '%s' "${2:-inst-1}" | shasum | cut -d' ' -f1)"
}
# pull_request <state> <head commit>: what GitHub knows about the branch's pull request.
pull_request() { jq -n --arg state "$1" --arg head "$2" '{state: $state, headRefOid: $head}' > "$GH_STUB/pr.json"; }

removed() { grep -qx -- "worktree rm --worktree id:card-1 --json" "$ORCA_STUB/calls"; }
# not_removed: the run listed the cards and asked Orca to remove none.
not_removed() {
  grep -q "^worktree list" "$ORCA_STUB/calls" || { echo "worktree-cleanup never listed the cards"; return 1; }
  if grep "worktree rm" "$ORCA_STUB/calls"; then return 1; fi
}

@test "a merged worktree completed for 14 days is removed, and its branch is kept" {
  cards completed
  commit
  merge
  completed_days_ago 14
  run "$kit/bin/wk" worktree-cleanup
  [ "$status" -eq 0 ]
  removed
  [[ "$output" == *"removed  task: branch task is merged and the card was completed 14 days ago; the branch stays"* ]]
  [[ "$output" == *"worktree-cleanup: removed 1, kept 0"* ]]
  if grep -e "--delete-branch" -e "--force" "$ORCA_STUB/calls"; then return 1; fi
}

@test "a merged worktree completed for 13 days is kept" {
  cards completed
  commit
  merge
  completed_days_ago 13
  run "$kit/bin/wk" worktree-cleanup
  [ "$status" -eq 0 ]
  not_removed
  [[ "$output" == *"kept     task: completed 13 days ago; it is removed after 14 days"* ]]
}

@test "a card seen completed for the first time starts its 14 days now" {
  cards completed
  commit
  merge
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: completed 0 days ago"* ]]
  completed_days_ago 14
  "$kit/bin/wk" worktree-cleanup
  removed
}

@test "a card that is not completed is kept, and its 14 days start again" {
  cards in-review
  commit
  merge
  completed_days_ago 30
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: the card is in-review, not completed"* ]]
  cards completed
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: completed 0 days ago"* ]]
}

@test "a branch that is not merged is kept" {
  cards completed
  commit
  completed_days_ago 30
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: branch task is not merged into main"* ]]
}

@test "a merged pull request counts as merged, even without a merge commit" {
  cards completed
  commit
  pull_request MERGED "$(git -C "$tree" rev-parse HEAD)"
  completed_days_ago 30
  "$kit/bin/wk" worktree-cleanup
  removed
}

@test "a commit made after the pull request was merged keeps the worktree" {
  cards completed
  commit
  pull_request MERGED "$(git -C "$tree" rev-parse HEAD)"
  commit
  completed_days_ago 30
  "$kit/bin/wk" worktree-cleanup
  not_removed
}

@test "an open pull request does not count as merged" {
  cards completed
  commit
  pull_request OPEN "$(git -C "$tree" rev-parse HEAD)"
  completed_days_ago 30
  "$kit/bin/wk" worktree-cleanup
  not_removed
}

@test "a worktree with an untracked file is kept and reported" {
  cards completed
  commit
  merge
  touch "$tree/notes.txt"
  completed_days_ago 30
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: it has uncommitted or untracked files"* ]]
}

@test "a worktree with an uncommitted change is kept and reported" {
  cards completed
  echo one > "$tree/file.txt"
  git -C "$tree" add file.txt
  git -C "$tree" commit -q -m "feat: file"
  merge
  echo two > "$tree/file.txt"
  completed_days_ago 30
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: it has uncommitted or untracked files"* ]]
}

@test "the main checkout is never removed" {
  cards completed
  commit
  merge
  completed_days_ago 30
  completed_days_ago 30 inst-0
  "$kit/bin/wk" worktree-cleanup
  if grep "worktree rm --worktree id:card-0" "$ORCA_STUB/calls"; then return 1; fi
}

@test "a card without a base ref is kept unless its pull request is merged" {
  cards completed
  jq 'del(.result.worktrees[1].baseRef)' "$ORCA_STUB/list.json" > "$ORCA_STUB/list.json.new"
  mv "$ORCA_STUB/list.json.new" "$ORCA_STUB/list.json"
  commit
  merge
  completed_days_ago 30
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: branch task is not merged, and GitHub"* ]]
}

@test "the worktree the command runs in is kept" {
  cards completed
  commit
  merge
  completed_days_ago 30
  cd "$tree"
  run "$kit/bin/wk" worktree-cleanup
  not_removed
  [[ "$output" == *"kept     task: this command runs inside it"* ]]
}

@test "a worktree whose folder is gone is kept and reported" {
  cards completed
  completed_days_ago 30
  rm -rf "$tree"
  run "$kit/bin/wk" worktree-cleanup
  [ "$status" -eq 0 ]
  not_removed
  [[ "$output" == *"kept     task: its folder $tree is missing"* ]]
}

@test "--dry-run removes nothing and says what would be removed" {
  cards completed
  commit
  merge
  completed_days_ago 14
  run "$kit/bin/wk" worktree-cleanup --dry-run
  [ "$status" -eq 0 ]
  not_removed
  [[ "$output" == *"would remove  task: branch task is merged"* ]]
  [[ "$output" == *"worktree-cleanup: would remove 1, kept 0"* ]]
}

@test "--dry-run still notes when a card was first seen completed" {
  cards completed
  commit
  merge
  "$kit/bin/wk" worktree-cleanup --dry-run
  is "$(find "$state/completed" -type f | wc -l | tr -d ' ')" 1
}

@test "when Orca refuses a removal, the worktree is reported as kept and the run fails" {
  cards completed
  commit
  merge
  completed_days_ago 30
  echo "worktree is locked" > "$ORCA_STUB/rm-fails"
  run "$kit/bin/wk" worktree-cleanup
  [ "$status" -eq 1 ]
  [[ "$output" == *"kept     task: Orca did not remove it: worktree is locked"* ]]
  [[ "$output" == *"worktree-cleanup: removed 0, kept 1"* ]]
}

@test "a list that Orca cut short is reported" {
  cards in-progress
  jq '.result.truncated = true' "$ORCA_STUB/list.json" > "$ORCA_STUB/list.json.new"
  mv "$ORCA_STUB/list.json.new" "$ORCA_STUB/list.json"
  run "$kit/bin/wk" worktree-cleanup
  [ "$status" -eq 1 ]
  [[ "$output" == *"Orca listed only a part of the worktrees"* ]]
}

@test "when Orca is not running, nothing is removed and the run fails with the reason" {
  cards completed
  touch "$ORCA_STUB/down"
  run "$kit/bin/wk" worktree-cleanup
  [ "$status" -eq 1 ]
  [[ "$output" == *"Orca is not running"* ]]
  is "$(cat "$ORCA_STUB/calls")" "status --json"
}

@test "an unknown flag is refused" {
  run "$kit/bin/wk" worktree-cleanup --force
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: wk worktree-cleanup [--dry-run]"* ]]
}

@test "wk adopt creates the daily cleanup automation, with a precheck that starts a run only when there is something to remove" {
  mkdir "$HOME/projects/new" && cd "$HOME/projects/new"
  "$kit/libexec/wk-adopt" > /dev/null
  call=$(grep "^automations create --name Worktree cleanup: new " "$ORCA_STUB/calls")
  [[ "$call" == *"--trigger daily"* ]]
  [[ "$call" == *"--precheck cd \"$HOME/projects/new\" && \"$HOME/kit/bin/wk\" worktree-cleanup --dry-run | grep -q \"^would remove\""* ]]
  [[ "$call" == *"--workspace path:$HOME/projects/new"* ]]
}
