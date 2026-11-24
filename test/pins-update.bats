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
  local package skill
  package="$NPX_STUB/someone/skills#$(git -C "$skills_repo" rev-parse HEAD)"
  mkdir -p "$package"
  for skill in "$skills_repo"/*/; do cp -R "${skill%/}" "$package/"; done
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
  is "$(cat "$GH_STUB/merged-head")" "$(git -C "$origin" rev-parse "$(pr_branch)")"
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
  [[ "$(last_line)" == *"waits for you; failed: upstream change under 50 lines (added plus removed): 0 lines; lines cannot measure this: skills/alpha has a binary file" ]]
}

@test "one very long changed line counts as one line, so the pull request waits" {
  skill_version "line one"$'\n'"$(printf 'x%.0s' $(seq 1 1100))"
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == *"waits for you; failed: upstream change under 50 lines (added plus removed): 2 lines; lines cannot measure this: skills/alpha has a changed line over 1000 characters" ]]
}

@test "a diff too long to show in full makes the pull request wait" {
  long=$(printf 'x%.0s' $(seq 1 3000))
  skill_version "$long"$'\n'"line two"
  echo "someone/skills#$(git -C "$skills_repo" rev-parse HEAD) alpha" > "$HOME/kit/skills.txt"
  push_kit "chore: pin a skill with a long line"
  skill_version "$long"$'\n'"line two"$'\n'"$(for _ in $(seq 1 48); do printf 'y%.0s' $(seq 1 999); echo; done)"
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == *"waits for you; failed: upstream change under 50 lines (added plus removed): 48 lines; lines cannot measure this: the diff is over 50000 characters"* ]]
}

@test "a new symbolic link upstream makes the pull request wait" {
  ln -s SKILL.md "$skills_repo/alpha/link.md"
  skill_version $'line one\nline two'
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == *"waits for you; failed: upstream change under 50 lines"*"skills/alpha has a symbolic link" ]]
}

@test "a file that becomes a program upstream makes the pull request wait" {
  chmod +x "$skills_repo/alpha/SKILL.md"
  skill_version $'line one\nline two'
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == *"waits for you; failed: upstream change under 50 lines"*"skills/alpha has a file mode change" ]]
}

@test "the installs of the run see no token and no config path of the real home" {
  skill_version $'line one\nline two, reworded'
  GH_TOKEN=secret NODE_OPTIONS=--require=/x GIT_CONFIG_GLOBAL="$HOME/.gitconfig" "$kit/bin/wk" pins-update
  is "$(grep -cxE 'GH_TOKEN|NODE_OPTIONS|GIT_CONFIG_GLOBAL' "$NPX_STUB/env")" 0
  grep -qx HOME "$NPX_STUB/env"
}

@test "two lines of one package in skills.txt move together, shown once" {
  mkdir -p "$skills_repo/beta"
  echo "beta text" > "$skills_repo/beta/SKILL.md"
  skill_version $'line one\nline two'
  old=$(git -C "$skills_repo" rev-parse HEAD)
  printf 'someone/skills#%s alpha\nsomeone/skills#%s beta\n' "$old" "$old" > "$HOME/kit/skills.txt"
  push_kit "feat: pin beta"
  skill_version $'line one\nline two, reworded'
  new=$(git -C "$skills_repo" rev-parse HEAD)
  "$kit/bin/wk" pins-update
  is "$(git -C "$origin" show "$(pr_branch):skills.txt")" "someone/skills#$new alpha"$'\n'"someone/skills#$new beta"
  is "$(grep -c '^| \[someone/skills\]' "$GH_STUB/pr-body.md")" 1
}

@test "a branch left by a run whose pull request failed is replaced by the next run" {
  touch "$GH_STUB/fail-create"
  skill_version $'line one\nline two, reworded'
  # An older date, so the next run's commit differs even within the same second.
  GIT_AUTHOR_DATE=2026-01-01T00:00:00 GIT_COMMITTER_DATE=2026-01-01T00:00:00 run "$kit/bin/wk" pins-update
  [ "$status" -ne 0 ]
  rm "$GH_STUB/fail-create"
  run "$kit/bin/wk" pins-update
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed the branch pins-update/"*", which an earlier run left without a pull request"* ]]
  [[ "$(last_line)" == "pins-update: merged https://github.com/test/kit/pull/1 "* ]]
}

@test "an agent that is gone upstream stops the run and says what to change" {
  git -C "$agents_repo" rm -q agents/reviewer.md
  echo "other" > "$agents_repo/README.md"
  git -C "$agents_repo" add -A
  git -C "$agents_repo" commit -q -m "feat: drop reviewer"
  run "$kit/bin/wk" pins-update
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no agent 'reviewer'; nothing was pushed. Remove it from agents/agents.toml"* ]]
  is "$(branches)" "main"
}

@test "a package name that git could read as an option is refused before any network call" {
  echo "--upload-pack=x/skills#$(git -C "$skills_repo" rev-parse HEAD) alpha" > "$HOME/kit/skills.txt"
  push_kit "chore: bad package"
  run "$kit/bin/wk" pins-update
  [ "$status" -ne 0 ]
  [[ "$output" == *"'--upload-pack=x/skills' is not a package"* ]]
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
  [[ "$(last_line)" == "pins-update: https://github.com/test/kit/pull/1 waits for you; failed: \`wk skills-sync\` and \`wk agents-sync\` succeed, so every patch still applies: \`wk skills-sync\` failed:" ]]
  no_gh_call "^pr merge"
  [[ "$(cat "$GH_STUB/pr-body.md")" == *"patches/skills/alpha.patch no longer applies"* ]]
  [[ "$(cat "$GH_STUB/pr-body.md")" == *"Do not merge it."*"1. Close this pull request."* ]]
}

@test "after the owner closes that pull request and fixes the patch, the next run offers the versions again" {
  mkdir -p "$HOME/kit/patches/skills"
  printf -- '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,2 +1,2 @@\n line one\n-line two\n+line two, patched\n' > "$HOME/kit/patches/skills/alpha.patch"
  push_kit "feat: patch alpha"
  skill_version $'line one\nline two, reworded'
  "$kit/bin/wk" pins-update
  jq -c '.[0].state = "CLOSED"' "$GH_STUB/prs.json" > "$GH_STUB/prs.json.new"
  mv "$GH_STUB/prs.json.new" "$GH_STUB/prs.json"
  printf -- '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,2 +1,2 @@\n line one\n-line two, reworded\n+line two, patched\n' > "$HOME/kit/patches/skills/alpha.patch"
  push_kit "fix: fit the alpha patch to the new text"
  run "$kit/bin/wk" pins-update
  [[ "$(last_line)" == "pins-update: merged https://github.com/test/kit/pull/2 "* ]]
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
