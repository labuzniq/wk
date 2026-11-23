#!/usr/bin/env bats
# `wk pins-update`: newer upstream versions of the pinned skills and agents become a pull request, merged by the run when the three conditions hold.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  # The upstream repos are local: "https://github.com/someone/skills" resolves to a folder.
  git config --global "url.$HOME/upstreams/.insteadOf" "https://github.com/"
  skills_repo="$HOME/upstreams/someone/skills"
  agents_repo="$HOME/upstreams/someone/agents"
  new_repo "$skills_repo"
  new_repo "$agents_repo"
  git -C "$agents_repo" config uploadpack.allowAnySHA1InWant true
  skill_version $'line one\nline two'
  agent_version "Be kind."

  echo "someone/skills#$(git -C "$skills_repo" rev-parse HEAD) alpha" > "$HOME/kit/skills.txt"
  printf '[source]\nrepo = "%s"\ncommit = "%s"\n\n[agents]\nreviewer = { skills = [] }\n' \
    "$agents_repo" "$(git -C "$agents_repo" rev-parse HEAD)" > "$HOME/kit/agents/agents.toml"
  "$kit/bin/wk" skills-sync > /dev/null
  "$kit/bin/wk" agents-sync > /dev/null
  rm "$HOME/kit/templates"
  origin="$HOME/origin.git"
  git init -q --bare "$origin"
  git init -q "$HOME/kit"
  git -C "$HOME/kit" remote add origin "$origin"
  push_kit "chore: start"
}

# skill_version <text>: a new upstream commit of the skill alpha, also known to the npx stand-in.
skill_version() {
  mkdir -p "$skills_repo/alpha"
  printf '%s\n' "$1" > "$skills_repo/alpha/SKILL.md"
  git -C "$skills_repo" add -A
  git -C "$skills_repo" commit -q -m "feat: alpha"
  local package
  package="$NPX_STUB/someone/skills#$(git -C "$skills_repo" rev-parse HEAD)"
  mkdir -p "$package"
  cp -R "$skills_repo/alpha" "$package/alpha"
}

# agent_version <last line>: a new upstream commit of the agent reviewer.
agent_version() {
  mkdir -p "$agents_repo/agents"
  printf -- '---\nname: reviewer\n---\nReview the code.\n%s\n' "$1" > "$agents_repo/agents/reviewer.md"
  git -C "$agents_repo" add -A
  git -C "$agents_repo" commit -q -m "feat: reviewer"
}

# push_kit <message>: commit what is in the installed kit and push it to its origin.
push_kit() {
  git -C "$HOME/kit" add -A
  git -C "$HOME/kit" commit -q -m "$1"
  git -C "$HOME/kit" push -q origin main
}

# skill_with_added_lines <n>: upstream adds n lines to the skill alpha.
skill_with_added_lines() { skill_version "$(printf 'line one\nline two\n'; seq -f 'added %g' 1 "$1")"; }

# Every file of the install and of the installed kit, with its checksum.
live() { find "$HOME/.agents" "$HOME/.claude" "$HOME/kit" -type f -exec shasum {} + | sort; }

branches() { git -C "$origin" for-each-ref --format='%(refname:short)' refs/heads | paste -sd' ' -; }
pr_branch() { jq -r '.[-1].headRefName' "$GH_STUB/prs.json"; }
last_line() { printf '%s\n' "$output" | tail -1; }
# no_gh_call <pattern>: fails when gh was called in a way that matches.
no_gh_call() { if grep -E "$1" "$GH_STUB/calls"; then echo "gh was called this way, and should not have been"; return 1; fi; }

@test "no newer version: no pull request" {
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  is "$output" "pins-update: every pin is at the newest upstream commit; no pull request"
  is "$(branches)" "main"
  is "$(cat "$GH_STUB/calls")" ""
}

@test "a small upstream change becomes a pull request that the run merges, reported in one line with the way to undo it" {
  skill_version $'line one\nline two, reworded'
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  url=https://github.com/test/kit/pull/1
  is "$(last_line)" "pins-update: merged $url (2 upstream lines changed); to undo it, run \`gh pr revert $url\` and merge the pull request it opens"
  is "$(jq -r '.[0].state' "$GH_STUB/prs.json")" MERGED
  grep -q "^pr merge $url --squash --delete-branch$" "$GH_STUB/calls"
}

@test "the pull request branch holds the new pins and the lock files written for them" {
  skill_version $'line one\nline two, reworded'
  agent_version "Be kind and brief."
  "$kit/bin/wk" pins-update
  new_skills=$(git -C "$skills_repo" rev-parse HEAD)
  new_agents=$(git -C "$agents_repo" rev-parse HEAD)
  is "$(git -C "$origin" show "$(pr_branch):skills.txt")" "someone/skills#$new_skills alpha"
  is "$(git -C "$origin" show "$(pr_branch):skills.lock" | jq -r '.skills.alpha.commit')" "$new_skills"
  is "$(git -C "$origin" show "$(pr_branch):agents/agents.toml" | grep -c "commit = \"$new_agents\"")" 1
  is "$(git -C "$origin" show "$(pr_branch):agents/agents.lock" | jq -r '.commit')" "$new_agents"
  is "$(git -C "$origin" show --format= --name-only "$(pr_branch)" | sort | paste -sd' ' -)" "agents/agents.lock agents/agents.toml skills.lock skills.txt"
}

@test "the pull request shows what changed upstream: sources, lines per skill and agent, and the diff" {
  old_skills=$(git -C "$skills_repo" rev-parse HEAD)
  skill_version $'line one\nline two, reworded'
  agent_version "Be kind and brief."
  "$kit/bin/wk" pins-update
  body=$(cat "$GH_STUB/pr-body.md")
  [[ "$body" == *"| [someone/skills](https://github.com/someone/skills/compare/$old_skills...$(git -C "$skills_repo" rev-parse HEAD)) | \`${old_skills:0:10}\` |"* ]]
  [[ "$body" == *"4 lines (2 added, 2 removed)"* ]]
  [[ "$body" == *'| `skills/alpha` | 1 | 1 |'* ]]
  [[ "$body" == *'| `agents/reviewer` | 1 | 1 |'* ]]
  [[ "$body" == *$'-line two\n+line two, reworded'* ]]
  [[ "$body" == *$'-Be kind.\n+Be kind and brief.'* ]]
  [[ "$body" == *'| `wk doctor` reports no gap for the new install | pass |'* ]]
  [[ "$body" == *"every condition holds"* ]]
}

@test "the installed skills, agents and kit stay as they are while the run works" {
  skill_version $'line one\nline two, reworded'
  agent_version "Be kind and brief."
  before=$(live)
  "$kit/bin/wk" pins-update
  is "$(live)" "$before"
  is "$(git -C "$HOME/kit" status --porcelain)" ""
  is "$(git -C "$HOME/kit" branch --show-current)" "main"
}

@test "49 changed upstream lines are merged" {
  skill_with_added_lines 47
  agent_version "Be kind and brief."
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == "pins-update: merged "*"(49 upstream lines changed)"* ]]
}

@test "50 changed upstream lines wait for the owner" {
  skill_with_added_lines 48
  agent_version "Be kind and brief."
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  is "$(last_line)" "pins-update: https://github.com/test/kit/pull/1 waits for you; failed: upstream change under 50 lines (added plus removed): 50 lines"
  is "$(jq -r '.[0].state' "$GH_STUB/prs.json")" OPEN
  no_gh_call "^pr merge"
  [[ "$(cat "$GH_STUB/pr-body.md")" == *"| upstream change under 50 lines (added plus removed) | **fail**: 50 lines |"* ]]
  [[ "$(cat "$GH_STUB/pr-body.md")" == *"waits for the owner"* ]]
}

@test "a changed binary file cannot be counted, so the pull request waits" {
  printf '\0\1\2' > "$skills_repo/alpha/logo.bin"
  skill_version $'line one\nline two'
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == *"waits for you; failed: upstream change under 50 lines (added plus removed): 0 lines; a binary file changed in skills/alpha, and its lines cannot be counted" ]]
}

@test "a patch of this repo does not count as an upstream change" {
  mkdir -p "$HOME/kit/patches/skills"
  printf -- '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,2 +1,2 @@\n-line one\n+line one, patched\n line two\n' > "$HOME/kit/patches/skills/alpha.patch"
  push_kit "feat: patch alpha"
  skill_version $'line one\nline two\nline three'
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == "pins-update: merged "*"(1 upstream lines changed)"* ]]
  [ -n "$(git -C "$origin" show "$(pr_branch):skills.lock" | jq -r '.skills.alpha.patch_sha256')" ]
}

@test "a patch that no longer applies: the pull request waits and names the patch" {
  mkdir -p "$HOME/kit/patches/skills"
  printf -- '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,2 +1,2 @@\n line one\n-line two\n+line two, patched\n' > "$HOME/kit/patches/skills/alpha.patch"
  push_kit "feat: patch alpha"
  skill_version $'line one\nline two, reworded'
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  [[ "$(last_line)" == "pins-update: https://github.com/test/kit/pull/1 waits for you; failed: every patch still applies"* ]]
  no_gh_call "^pr merge"
  [[ "$(cat "$GH_STUB/pr-body.md")" == *"patches/skills/alpha.patch no longer applies"* ]]
  [[ "$(cat "$GH_STUB/pr-body.md")" == *"The lock files in this pull request are not complete."* ]]
}

@test "a doctor gap in the new install: the pull request waits and shows the gap" {
  mkdir -p "$HOME/kit/patches/skills"
  echo "a patch for a skill nobody pins" > "$HOME/kit/patches/skills/ghost.patch"
  push_kit "feat: patch ghost"
  skill_version $'line one\nline two, reworded'
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == *"waits for you; failed: \`wk doctor\` reports no gap for the new install: patches: patches/skills/ghost.patch is not applied"* ]]
  no_gh_call "^pr merge"
}

@test "a merge that GitHub refuses leaves the pull request waiting and says why" {
  touch "$GH_STUB/merge-refused"
  skill_version $'line one\nline two, reworded'
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  is "$(last_line)" "pins-update: https://github.com/test/kit/pull/1 waits for you; every condition holds, but the merge failed: the base branch policy prohibits the merge"
}

@test "while a pin update waits, a second run opens no second pull request" {
  skill_with_added_lines 60
  "$kit/bin/wk" pins-update
  skill_with_added_lines 61
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  is "$output" "pins-update: https://github.com/test/kit/pull/1 still waits for you; no new pull request until it is merged or closed"
  is "$(grep -c "^pr create" "$GH_STUB/calls")" 1
  is "$(branches)" "main $(pr_branch)"
}

@test "a closed pull request is the remembered no: the same versions are not offered again" {
  skill_with_added_lines 60
  "$kit/bin/wk" pins-update
  jq -c '.[0].state = "CLOSED"' "$GH_STUB/prs.json" > "$GH_STUB/prs.json.new"
  mv "$GH_STUB/prs.json.new" "$GH_STUB/prs.json"
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  is "$output" "pins-update: these versions were offered in https://github.com/test/kit/pull/1, which is closed; no new pull request"
  is "$(grep -c "^pr create" "$GH_STUB/calls")" 1
}

@test "after a closed pull request, a newer upstream version is offered" {
  skill_with_added_lines 60
  "$kit/bin/wk" pins-update
  jq -c '.[0].state = "CLOSED"' "$GH_STUB/prs.json" > "$GH_STUB/prs.json.new"
  mv "$GH_STUB/prs.json.new" "$GH_STUB/prs.json"
  skill_with_added_lines 61
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == "pins-update: https://github.com/test/kit/pull/2 waits for you"* ]]
}

@test "a dry run prints the pull request text and the verdict, and pushes nothing" {
  skill_version $'line one\nline two, reworded'
  run "$kit/bin/wk" pins-update --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"+line two, reworded"* ]]
  is "$(last_line)" "pins-update: dry run, nothing was pushed; the pull request would be merged"
  is "$(branches)" "main"
  no_gh_call "^pr (create|merge)"
}

@test "upstream text with a code fence cannot close the fence around the diff" {
  skill_version $'line one\n```\nline two\n```'
  "$kit/bin/wk" pins-update
  [[ "$(cat "$GH_STUB/pr-body.md")" == *$'\n````diff\n'* ]]
}

@test "a skill that is gone upstream stops the run before anything is pushed" {
  rm -r "$skills_repo/alpha"
  git -C "$skills_repo" commit -q -am "feat: drop alpha"
  mkdir -p "$NPX_STUB/someone/skills#$(git -C "$skills_repo" rev-parse HEAD)"
  run "$kit/bin/wk" pins-update
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing was pushed"*"has no skill 'alpha'"* ]]
  is "$(branches)" "main"
}
