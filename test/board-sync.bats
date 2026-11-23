#!/usr/bin/env bats
# Board status rules: `wk board-sync` moves a card forward from git and pull request state.

load helpers

setup() {
  setup_home
  repo="$HOME/projects/demo"
  new_repo "$repo"
  git -C "$repo" checkout -q -b task
}

# card <status> [isMainWorktree]: the card Orca reports for the checkout in $repo.
card() {
  jq -n --arg path "$repo" --arg status "$1" --argjson main "${2:-false}" \
    '{result: {worktree: {id: "card-1", repoId: "repo-1", path: $path, branch: "refs/heads/task", baseRef: "main",
      workspaceStatus: $status, isMainWorktree: $main, displayName: "task"}}}' > "$ORCA_STUB/current.json"
}

commit() { git -C "$repo" commit -q --allow-empty -m "feat: work"; }
pushed() { git -C "$repo" update-ref refs/remotes/origin/task HEAD; }
pull_request() { echo "$1" > "$GH_STUB/pr-state"; }

moved_to() { grep -qx -- "worktree set --worktree id:card-1 --workspace-status $1 --json" "$ORCA_STUB/calls"; }
not_moved() { if grep -q "worktree set" "$ORCA_STUB/calls"; then return 1; fi; }

@test "a todo card with no work stays todo" {
  card todo
  "$kit/bin/wk" board-sync
  not_moved
}

@test "an uncommitted file moves a todo card to in-progress" {
  card todo
  touch "$repo/notes.txt"
  "$kit/bin/wk" board-sync
  moved_to in-progress
}

@test "a commit moves a todo card to in-progress" {
  card todo
  commit
  "$kit/bin/wk" board-sync
  moved_to in-progress
}

@test "a merge commit into the base completes the card" {
  card in-progress
  commit
  git -C "$repo" checkout -q main
  git -C "$repo" merge -q --no-ff -m "merge task" task
  git -C "$repo" checkout -q task
  "$kit/bin/wk" board-sync
  moved_to completed
}

@test "a merge into another branch does not complete the card" {
  card in-progress
  commit
  git -C "$repo" checkout -q -b other main
  git -C "$repo" merge -q --no-ff -m "merge task" task
  git -C "$repo" checkout -q task
  "$kit/bin/wk" board-sync
  not_moved
}

@test "a branch with no commits of its own is not completed" {
  card in-progress
  "$kit/bin/wk" board-sync
  not_moved
}

@test "an open pull request moves the card to in-review" {
  card in-progress
  commit
  pushed
  pull_request "OPEN "
  "$kit/bin/wk" board-sync
  moved_to in-review
}

@test "requested changes move the card back to in-progress" {
  card in-review
  commit
  pushed
  pull_request "OPEN CHANGES_REQUESTED"
  "$kit/bin/wk" board-sync
  moved_to in-progress
}

@test "a merged pull request completes the card, even without a merge commit" {
  card in-review
  commit
  pushed
  pull_request "MERGED APPROVED"
  "$kit/bin/wk" board-sync
  moved_to completed
}

@test "a completed card is never moved back" {
  card completed
  commit
  pushed
  pull_request "OPEN CHANGES_REQUESTED"
  "$kit/bin/wk" board-sync
  not_moved
}

@test "gh is not asked for a branch that is not on origin" {
  card in-progress
  commit
  pull_request "OPEN "
  "$kit/bin/wk" board-sync
  [ ! -s "$GH_STUB/calls" ]
  not_moved
}

@test "gh is asked at most once per ten minutes per worktree" {
  card in-progress
  commit
  pushed
  pull_request "OPEN "
  "$kit/bin/wk" board-sync
  "$kit/bin/wk" board-sync
  [ "$(wc -l < "$GH_STUB/calls")" -eq 1 ]
}

@test "the main checkout is never moved" {
  card todo true
  touch "$repo/notes.txt"
  "$kit/bin/wk" board-sync
  not_moved
}

@test "--repo syncs every card of the repo" {
  card todo
  commit
  other="$HOME/projects/other"
  new_repo "$other"
  touch "$other/notes.txt"
  jq --arg other "$other" '{result: {worktrees: [.result.worktree, (.result.worktree | .id = "card-2" | .path = $other | .branch = "refs/heads/main")]}}' \
    "$ORCA_STUB/current.json" > "$ORCA_STUB/list.json"
  "$kit/bin/wk" board-sync --repo
  moved_to in-progress
  grep -qx -- "worktree set --worktree id:card-2 --workspace-status in-progress --json" "$ORCA_STUB/calls"
}

@test "the current card is saved for the session-start hook" {
  card in-progress
  "$kit/bin/wk" board-sync
  saved="$state/cards/$(printf '%s' "$repo" | shasum | cut -d' ' -f1).json"
  [ "$(jq -r '.result.worktree.displayName' "$saved")" = task ]
}

@test "when Orca is not running, nothing happens and the command succeeds" {
  card todo
  touch "$repo/notes.txt" "$ORCA_STUB/down"
  "$kit/bin/wk" board-sync
  not_moved
}
