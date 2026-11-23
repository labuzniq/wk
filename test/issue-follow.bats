#!/usr/bin/env bats
# A workspace follows its issue: `wk board-sync` completes the card of a closed issue, puts each new issue comment on the card once, and names the issue in the pull request.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  repo="$HOME/projects/demo"
  new_repo "$repo"
  git -C "$repo" checkout -q -b task
}

# card <status> [linked issue]: the card Orca reports for the checkout in $repo, created at 2026-01-01 00:00 UTC.
card() {
  jq -n --arg path "$repo" --arg status "$1" --argjson issue "${2:-7}" \
    '{result: {worktree: {id: "card-1", repoId: "repo-1", path: $path, branch: "refs/heads/task", baseRef: "main",
      workspaceStatus: $status, isMainWorktree: false, displayName: "task", linkedIssue: $issue, createdAt: 1767225600000,
      comment: "tests pass; next: review\ngoal: follow the issue"}}}' > "$ORCA_STUB/current.json"
}

# issue <state> [comments as JSON]: what GitHub knows about issue 7.
issue() { jq -n --arg state "$1" --argjson comments "${2:-[]}" '{state: $state, comments: $comments}' > "$GH_STUB/issue.json"; }
# said <id> <author> <text> [time]: one issue comment as JSON, by default written after the card was created.
said() {
  jq -cn --arg id "$1" --arg author "$2" --arg body "$3" --arg at "${4:-2026-02-01T10:00:00Z}" \
    '{id: $id, author: {login: $author}, body: $body, createdAt: $at}'
}
# pull_request <body> [closing issue numbers as JSON]: an open pull request on the pushed branch.
pull_request() {
  git -C "$repo" commit -q --allow-empty -m "feat: work"
  git -C "$repo" update-ref refs/remotes/origin/task HEAD
  jq -n --arg body "$1" --argjson closes "${2:-[]}" \
    '{state: "OPEN", reviewDecision: "", body: $body, closingIssuesReferences: ($closes | map({number: .}))}' > "$GH_STUB/pr.json"
}

sync() { "$kit/bin/wk" board-sync; }
ten_minutes_later() { find "$state/gh" -type f -exec touch -t 202001010000 {} +; }
card_comment() { jq -r '.result.worktree.comment' "$ORCA_STUB/current.json"; }
moved_to() { grep -qx -- "worktree set --worktree id:card-1 --workspace-status $1 --json" "$ORCA_STUB/calls"; }
# untouched: the sync read the card and changed neither its status nor its comment.
untouched() {
  grep -q "^worktree current" "$ORCA_STUB/calls" || { echo "board-sync never read the card"; return 1; }
  if grep "worktree set" "$ORCA_STUB/calls"; then return 1; fi
}

@test "a closed issue completes its card" {
  card in-progress
  issue CLOSED
  sync
  moved_to completed
}

@test "an open issue leaves the card where it is" {
  card in-progress
  issue OPEN
  sync
  untouched
}

@test "a reopened issue never moves a completed card back" {
  card completed
  issue OPEN "[$(said c1 anna "please look again")]"
  sync
  untouched
}

@test "a card without a linked issue asks GitHub for no issue" {
  card in-progress null
  issue CLOSED
  sync
  [ ! -s "$GH_STUB/calls" ]
  untouched
}

@test "a new issue comment is added to the card with its author, and the card's own lines stay" {
  card in-progress
  issue OPEN "[$(said c1 anna "the button is still grey")]"
  sync
  is "$(card_comment)" "tests pass; next: review
goal: follow the issue
issue comment by anna: the button is still grey"
}

@test "an issue comment reaches the card once, even after the agent rewrote the card comment" {
  card in-progress
  issue OPEN "[$(said c1 anna "first")]"
  sync
  card in-progress
  ten_minutes_later
  issue OPEN "[$(said c1 anna "first"),$(said c2 ben "second")]"
  sync
  is "$(card_comment)" "tests pass; next: review
goal: follow the issue
issue comment by ben: second"
}

@test "an issue comment of several lines becomes one line on the card, cut at 200 characters" {
  card in-progress
  issue OPEN "[$(said c1 anna "$(printf 'line one\n\nline two %0250d' 0)")]"
  sync
  is "$(card_comment | wc -l | tr -d ' ')" 3
  is "$(card_comment | tail -1 | cut -c1-42)" "issue comment by anna: line one line two 0"
  is "$(card_comment | tail -1 | wc -c | tr -d ' ')" "$((23 + 200 + 1))"
}

@test "a comment written before the workspace was created is not added" {
  card in-progress
  issue OPEN "[$(said c1 anna "old news" 2025-12-31T23:59:59Z)]"
  sync
  untouched
}

@test "a comment on an empty card comment starts at line 1" {
  card in-progress
  jq '.result.worktree.comment = null' "$ORCA_STUB/current.json" > "$ORCA_STUB/current.json.new"
  mv "$ORCA_STUB/current.json.new" "$ORCA_STUB/current.json"
  issue OPEN "[$(said c1 anna "hello")]"
  sync
  is "$(card_comment)" "issue comment by anna: hello"
}

@test "a comment that Orca did not store is tried again on the next sync" {
  card in-progress
  issue OPEN "[$(said c1 anna "hello")]"
  touch "$ORCA_STUB/set-fails"
  sync
  rm "$ORCA_STUB/set-fails"
  ten_minutes_later
  sync
  is "$(card_comment | tail -1)" "issue comment by anna: hello"
}

@test "a failed call to GitHub changes nothing and the command succeeds" {
  card in-progress
  issue CLOSED "[$(said c1 anna "hello")]"
  pull_request "Adds the thing."
  touch "$GH_STUB/down"
  sync
  untouched
  [ ! -f "$GH_STUB/pr-body" ]
}

@test "an answer from GitHub that is not JSON changes nothing and the command succeeds" {
  card in-progress
  echo "<html>502</html>" > "$GH_STUB/issue.json"
  sync
  untouched
}

@test "the issue is asked for at most once per ten minutes per worktree" {
  card in-progress
  issue OPEN
  sync
  sync
  is "$(cat "$GH_STUB/calls")" "issue view 7 --json state,comments"
  ten_minutes_later
  sync
  is "$(wc -l < "$GH_STUB/calls" | tr -d ' ')" 2
}

@test "a pull request that does not name the issue gets 'Closes #<number>' added to its body" {
  card in-progress
  issue OPEN
  pull_request "Adds the thing.
"
  run sync
  is "$output" "task: added 'Closes #7' to the pull request, so the merge closes the issue"
  is "$(cat "$GH_STUB/pr-body")" "Adds the thing.

Closes #7"
}

@test "a pull request with an empty body gets only the closing line" {
  card in-progress
  issue OPEN
  pull_request ""
  sync
  is "$(cat "$GH_STUB/pr-body")" "Closes #7"
}

@test "a pull request that GitHub already links to the issue is left alone" {
  card in-progress
  issue OPEN
  pull_request "Linked by hand in the sidebar." "[7]"
  sync
  [ ! -f "$GH_STUB/pr-body" ]
}

@test "a pull request whose body already names the issue is left alone" {
  card in-progress
  issue OPEN
  pull_request "Adds the thing.

fixes #7"
  sync
  [ ! -f "$GH_STUB/pr-body" ]
}

@test "a pull request that names another issue still gets its own" {
  card in-progress
  issue OPEN
  pull_request "Closes #70" "[70]"
  sync
  is "$(tail -1 "$GH_STUB/pr-body")" "Closes #7"
}

@test "the pull request of a card without a linked issue is left alone" {
  card in-progress null
  pull_request "Adds the thing."
  sync
  [ ! -f "$GH_STUB/pr-body" ]
}

@test "a merged pull request is not edited" {
  card in-review
  pull_request "Adds the thing."
  jq '.state = "MERGED"' "$GH_STUB/pr.json" > "$GH_STUB/pr.json.new"
  mv "$GH_STUB/pr.json.new" "$GH_STUB/pr.json"
  sync
  [ ! -f "$GH_STUB/pr-body" ]
  moved_to completed
}

@test "the stop hook returns without waiting for GitHub" {
  card in-progress
  issue CLOSED
  printf '#!/usr/bin/env bash\nsleep 5\n' > "$HOME/gh"
  chmod +x "$HOME/gh"
  start=$(date +%s)
  PATH="$HOME:$PATH" "$kit/hooks/stop.sh" <<<"{\"cwd\": \"$repo\"}"
  [ $(( $(date +%s) - start )) -lt 4 ]
}
