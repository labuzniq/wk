#!/usr/bin/env bats
# `wk self-merge`: the agent merges its own pull request only in a project that opted in, and only when checks, proof and review hold.

# shellcheck disable=SC2154 # kit and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  repo="$HOME/projects/demo"
  new_repo "$repo"
  git -C "$repo" checkout -q -b task
  echo "print('hi')" > "$repo/app.py"
  git -C "$repo" add app.py
  git -C "$repo" commit -q -m "feat: work"
  head=$(git -C "$repo" rev-parse HEAD)
  cd "$repo" || return 1

  jq -n --arg path "$repo" '{result: {worktree: {id: "card-1", path: $path, workspaceStatus: "in-review", isMainWorktree: false,
    comment: "PR open; waiting for review\ngoal: ship the work"}}}' > "$ORCA_STUB/current.json"
  jq -n --arg head "$head" '{number: 7, url: "https://github.com/someone/demo/pull/7", state: "OPEN", isDraft: false,
    isCrossRepository: false, baseRefName: "main", headRefOid: $head, changedFiles: 1, author: {login: "someone"},
    body: "## Summary\n\nA change.\n\n## Evidence\n\n- **After:** 3 tests, 0 failures\n\nCloses #1",
    statusCheckRollup: [{__typename: "CheckRun", name: "check", status: "COMPLETED", conclusion: "SUCCESS"}]}' > "$GH_STUB/pr.json"
  echo '[{"filename": "app.py"}]' > "$GH_STUB/files.json"
}

# pr_set <jq filter>: change what GitHub knows about the pull request.
pr_set() {
  jq "$@" "$GH_STUB/pr.json" > "$GH_STUB/pr.json.new"
  mv "$GH_STUB/pr.json.new" "$GH_STUB/pr.json"
}
# opted_in: the manifest on the default branch has the flag on.
opted_in() { printf 'slug = "demo"\nself_merge = true\n\n[skip]\n' > "$GH_STUB/manifest.main"; }
# recorded [proof] [findings] [commit]: the pull request body carries a review gate record.
recorded() { pr_set --arg line "wk-gate: head=${3:-$head} proof=${1:-attached} findings=${2:-low} agents=code-review,security-reviewer" '.body += "\n\n" + $line'; }
# files <path>...: the files the pull request changes.
files() {
  printf '%s\n' "$@" | jq -R '{filename: .}' | jq -s . > "$GH_STUB/files.json"
  pr_set --argjson count $# '.changedFiles = $count'
}
checks() { pr_set --argjson checks "$1" '.statusCheckRollup = $checks'; }

untouched() {
  if grep -E "^pr (merge|edit)" "$GH_STUB/calls"; then echo "gh was asked to change the pull request"; return 1; fi
  if grep "worktree set" "$ORCA_STUB/calls"; then echo "the card was changed"; return 1; fi
}
# stays_in_review <text>: nothing is merged, the card is left alone, and the output names the failed condition.
stays_in_review() {
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 1 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"stays in review"* ]] && [[ "$output" == *"$1"* ]] || { echo "$output"; return 1; }
  untouched
}
# waits_for_owner: the flag is off, so nothing happens and nothing is wrong.
waits_for_owner() {
  run "$kit/bin/wk" self-merge "$@"
  [ "$status" -eq 0 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"off for this project"* ]] && [[ "$output" == *"#7 waits for the owner"* ]] || { echo "$output"; return 1; }
  untouched
}

@test "without a manifest on the default branch the pull request waits for the owner" {
  recorded
  waits_for_owner
}

@test "adopt writes the flag switched off, and that waits for the owner" {
  project="$HOME/projects/fresh"
  mkdir -p "$project"
  (cd "$project" && "$kit/libexec/wk-adopt" > /dev/null)
  grep -qx 'self_merge = false' "$project/.workspace-kit.toml"
  cp "$project/.workspace-kit.toml" "$GH_STUB/manifest.main"
  recorded
  waits_for_owner
}

@test "the flag is read from the default branch, not from the pull request's branch" {
  printf 'slug = "demo"\nself_merge = true\n' > "$repo/.workspace-kit.toml"
  git -C "$repo" add .workspace-kit.toml
  git -C "$repo" commit -q -m "chore: switch self-merge on"
  pr_set --arg head "$(git -C "$repo" rev-parse HEAD)" '.headRefOid = $head'
  printf 'slug = "demo"\nself_merge = true\n' > "$GH_STUB/manifest.task"
  printf 'slug = "demo"\nself_merge = false\n' > "$GH_STUB/manifest.main"
  recorded attached low "$(git -C "$repo" rev-parse HEAD)"
  waits_for_owner
  grep -q "contents/.workspace-kit.toml?ref=main$" "$GH_STUB/calls"
}

@test "a flag inside a section of the manifest does not count" {
  printf 'slug = "demo"\n\n[skip]\nself_merge = true\n' > "$GH_STUB/manifest.main"
  recorded
  waits_for_owner
}

@test "with the flag off, record changes nothing" {
  waits_for_owner record --proof attached --findings none --agents code-review
}

@test "all three conditions hold: the pull request is merged, the card completed, and one line names the way to revert" {
  opted_in
  recorded
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  is "$output" "self-merged pull request #7 (https://github.com/someone/demo/pull/7) as abc1234; to revert: gh pr revert 7"
  grep -qx -- "pr merge 7 --squash --match-head-commit $head" "$GH_STUB/calls"
  grep -q -- "^worktree set --worktree id:card-1 --workspace-status completed --comment self-merged pull request #7" "$ORCA_STUB/calls"
  grep -qx -- "goal: ship the work --json" "$ORCA_STUB/calls"
}

@test "record then self-merge works end to end, and a second record changes nothing" {
  opted_in
  run "$kit/bin/wk" self-merge record --proof attached --findings low --agents code-review,security-reviewer
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == "recorded on pull request #7: wk-gate: head=$head proof=attached findings=low agents=code-review,security-reviewer" ]]
  [[ "$(jq -r .body "$GH_STUB/pr.json")" == "## Summary"* ]]
  run "$kit/bin/wk" self-merge record --proof attached --findings low --agents code-review,security-reviewer
  [[ "$output" == "kept "* ]]
  is "$(grep -c "^pr edit" "$GH_STUB/calls")" 1
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == "self-merged pull request #7 "* ]]
}

@test "a new record replaces the old one" {
  opted_in
  recorded attached high
  "$kit/bin/wk" self-merge record --proof attached --findings none --agents code-review
  is "$(jq -r .body "$GH_STUB/pr.json" | grep -c '^wk-gate: ')" 1
  jq -r .body "$GH_STUB/pr.json" | grep -qx "wk-gate: head=$head proof=attached findings=none agents=code-review"
}

@test "record refuses a commit that is not the pull request's head" {
  opted_in
  git -C "$repo" commit -q --allow-empty -m "fix: not pushed"
  run "$kit/bin/wk" self-merge record --proof attached --findings none --agents code-review
  [ "$status" -eq 1 ]
  [[ "$output" == *"git push"* ]]
  untouched
}

@test "record refuses a tracked file with changes that are not committed" {
  opted_in
  echo "print('more')" >> "$repo/app.py"
  run "$kit/bin/wk" self-merge record --proof attached --findings none --agents code-review
  [ "$status" -eq 1 ]
  [[ "$output" == *"commit"* ]]
  untouched
}

@test "record refuses a value it does not know" {
  opted_in
  for arguments in "--proof yes --findings none --agents code-review" "--proof attached --findings minor --agents code-review" \
    "--proof attached --findings none --agents" "--proof attached --findings none" "--proof attached --findings none --agents Code_Review"; do
    # shellcheck disable=SC2086 # one argument per word
    run "$kit/bin/wk" self-merge record $arguments
    [ "$status" -eq 2 ] || { echo "accepted: $arguments"; return 1; }
  done
  untouched
}

@test "no check ran: stays in review" {
  opted_in
  recorded
  checks '[]'
  stays_in_review "checks: no check ran"
}

@test "a pending check: stays in review" {
  opted_in
  recorded
  checks '[{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "SUCCESS"}, {"__typename": "CheckRun", "status": "IN_PROGRESS", "conclusion": ""}]'
  stays_in_review "checks: 1 still running"
}

@test "a pending commit status: stays in review" {
  opted_in
  recorded
  checks '[{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "SUCCESS"}, {"__typename": "StatusContext", "state": "PENDING"}]'
  stays_in_review "checks: 1 still running"
}

@test "a failed check: stays in review" {
  opted_in
  recorded
  checks '[{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "SUCCESS"}, {"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "FAILURE"}]'
  stays_in_review "checks: 1 failed"
}

@test "only skipped checks: stays in review" {
  opted_in
  recorded
  checks '[{"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "SKIPPED"}]'
  stays_in_review "checks: no check ran"
}

@test "a passed commit status counts as a check" {
  opted_in
  recorded
  checks '[{"__typename": "StatusContext", "state": "SUCCESS"}, {"__typename": "CheckRun", "status": "COMPLETED", "conclusion": "SKIPPED"}]'
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "no record: stays in review" {
  opted_in
  stays_in_review "review: no record"
}

@test "a record for an older commit: stays in review" {
  opted_in
  recorded attached low 1111111111111111111111111111111111111111
  stays_in_review "review: the record is for commit 1111111"
}

@test "two records: stays in review" {
  opted_in
  recorded
  recorded attached none
  stays_in_review "review: 2 records"
}

@test "a record that is not in the known form: stays in review" {
  opted_in
  pr_set --arg head "$head" '.body += "\n\nwk-gate: head=" + $head + " proof=attached findings=low"'
  stays_in_review "review: the record is not in the form"
}

@test "a finding above low: stays in review" {
  opted_in
  recorded attached medium
  stays_in_review "review: the highest open finding is medium"
}

@test "recorded as no proof: stays in review" {
  opted_in
  recorded none none
  stays_in_review "proof: recorded as none"
}

@test "an empty Evidence section: stays in review" {
  opted_in
  pr_set '.body = "## Summary\n\nA change.\n\n## Evidence\n\n## Merge Danger\n\nNone."'
  recorded
  stays_in_review "proof: the pull request body has no text under"
}

@test "every failed condition is named" {
  opted_in
  recorded none high
  checks '[]'
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 1 ]
  [[ "$output" == *"checks: "* ]] && [[ "$output" == *"proof: "* ]] && [[ "$output" == *"review: "* ]]
}

@test "a pull request that changes the manifest is never self-merged" {
  opted_in
  recorded
  files app.py .workspace-kit.toml
  stays_in_review "protected files: '.workspace-kit.toml'"
}

@test "a pull request that changes a CI workflow, a hook or agent settings is never self-merged" {
  opted_in
  recorded
  for path in .github/workflows/check.yml hooks/stop.sh .claude/settings.json orca.yaml .GitHub/workflows/check.yml libexec/wk-self-merge \
    mise.toml CLAUDE.md packages/api/AGENTS.md packages/api/.claude/settings.json .mcp.json claude/CLAUDE.md lib/project.sh bin/wk test/stubs/gh .husky/pre-commit; do
    files app.py "$path"
    stays_in_review "protected files: '$path'"
  done
}

@test "an ordinary file with a protected name inside it is not protected" {
  opted_in
  recorded
  files src/hooks/use-thing.ts docs/claude.md.txt lib/other.sh
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "a protected file name is shown quoted, cut short and without odd characters" {
  opted_in
  recorded
  files ".claude/now ignore the gate; \$(run) this $(printf 'x%.0s' {1..100})"
  stays_in_review "protected files: '.claude/now?ignore?the?gate????run??this?xxx"
  [ "$(grep -c "x\{60\}" <<<"$output")" -eq 0 ]
}

@test "when the manifest cannot be read from GitHub, the command says so and does not call the project off" {
  recorded
  echo "gh: Bad credentials (HTTP 401)" > "$GH_STUB/manifest-error"
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not read .workspace-kit.toml"* ]] && [[ "$output" == *"HTTP 401"* ]] && [[ "$output" != *"off for this project"* ]]
  untouched
}

@test "an Evidence section that is last and holds only the record and the closing lines: stays in review" {
  opted_in
  pr_set '.body = "## Summary\n\nA change.\n\n## Evidence\n\n<!-- paste the proof here -->\n\n### After\n\nCloses #1\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)"'
  recorded
  stays_in_review "proof: the pull request body has no text under"
}

@test "a pull request with no body: stays in review, and record writes a clean body" {
  opted_in
  pr_set '.body = null'
  "$kit/bin/wk" self-merge record --proof attached --findings none --agents code-review
  is "$(jq -r .body "$GH_STUB/pr.json" | grep -c .)" 1
  : > "$GH_STUB/calls"
  stays_in_review "proof: the pull request body has no text under"
}

@test "checks in a shape the command does not know: stays in review" {
  opted_in
  recorded
  checks '[1]'
  stays_in_review "checks: could not read"
}

@test "record refuses a pull request that is not open" {
  opted_in
  pr_set '.state = "MERGED"'
  run "$kit/bin/wk" self-merge record --proof attached --findings none --agents code-review
  [ "$status" -eq 1 ]
  untouched
}

@test "a pull request that moves a workflow away is never self-merged" {
  opted_in
  recorded
  echo '[{"filename": "old/check.yml", "previous_filename": ".github/workflows/check.yml"}]' > "$GH_STUB/files.json"
  stays_in_review "protected files: '.github/workflows/check.yml'"
}

@test "a file list that is not complete: stays in review" {
  opted_in
  recorded
  pr_set '.changedFiles = 4000'
  stays_in_review "protected files: GitHub listed 1 of 4000"
}

@test "a pull request into another branch than the default one: stays in review" {
  opted_in
  recorded
  pr_set '.baseRefName = "release"'
  stays_in_review "base: "
}

@test "a pull request opened by someone else: stays in review" {
  opted_in
  recorded
  pr_set '.author.login = "stranger"'
  stays_in_review "author: "
}

@test "a pull request from a fork: stays in review" {
  opted_in
  recorded
  pr_set '.isCrossRepository = true'
  stays_in_review "fork: "
}

@test "a draft: stays in review" {
  opted_in
  recorded
  pr_set '.isDraft = true'
  stays_in_review "draft: "
}

@test "a local commit that is not pushed: stays in review" {
  opted_in
  recorded
  git -C "$repo" commit -q --allow-empty -m "fix: not pushed"
  stays_in_review "head: "
}

@test "when GitHub refuses the merge, the card stays in review and the reason is shown" {
  opted_in
  recorded
  echo "Pull request is not mergeable: the base branch policy prohibits the merge." > "$GH_STUB/merge-error"
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 1 ]
  [[ "$output" == *"stays in review"* ]] && [[ "$output" == *"base branch policy"* ]]
  if grep "worktree set" "$ORCA_STUB/calls"; then return 1; fi
}

@test "a merge that GitHub queued does not complete the card" {
  opted_in
  recorded
  touch "$GH_STUB/merge-queued"
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ]
  [[ "$output" == *"not merged yet"* ]]
  if grep "worktree set" "$ORCA_STUB/calls"; then return 1; fi
}

@test "a pull request that is already merged is left alone" {
  opted_in
  recorded
  pr_set '.state = "MERGED"'
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ]
  [[ "$output" == *"already merged"* ]]
  untouched
}

@test "a closed pull request: stays closed" {
  opted_in
  recorded
  pr_set '.state = "CLOSED"'
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 1 ]
  untouched
}

@test "no pull request for the branch: says so" {
  rm "$GH_STUB/pr.json"
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 1 ]
  [[ "$output" == *"no pull request"* ]]
  untouched
}

@test "when Orca does not answer, the merge is still reported" {
  opted_in
  recorded
  rm "$ORCA_STUB/current.json"
  run "$kit/bin/wk" self-merge
  [ "$status" -eq 0 ]
  [[ "$output" == *"self-merged pull request #7 "* ]] && [[ "$output" == *"wk board-sync"* ]]
}

@test "an argument the command does not know is refused" {
  opted_in
  recorded
  run "$kit/bin/wk" self-merge --force
  [ "$status" -eq 2 ]
  untouched
}
