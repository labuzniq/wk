#!/usr/bin/env bats
# `wk skills-sync`: third-party skills are installed at a pinned commit, may carry a recorded patch, and the lock file records the result.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  upstream skills#c1 alpha $'line one\nline two'
  upstream skills#c1 beta "beta text"
  echo "someone/skills#c1 alpha beta" > "$HOME/kit/skills.txt"
  lock="$HOME/kit/skills.lock"
  alpha="$HOME/.agents/skills/alpha/SKILL.md"
}

# upstream <repo#commit> <skill> <text>: what the package someone/<repo> holds for the skill at that commit.
upstream() {
  mkdir -p "$NPX_STUB/someone/$1/$2"
  echo "$3" > "$NPX_STUB/someone/$1/$2/SKILL.md"
}

# patch_alpha <old second line> <new second line>: a recorded patch for the skill alpha.
patch_alpha() {
  mkdir -p "$HOME/kit/patches/skills"
  printf -- '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,2 +1,2 @@\n line one\n-%s\n+%s\n' "$1" "$2" > "$HOME/kit/patches/skills/alpha.patch"
}

installs() { wc -l < "$NPX_STUB/calls" | tr -d ' '; }

@test "each listed skill is installed at its pin and recorded in the lock file" {
  run "$kit/bin/wk" skills-sync
  [ "$status" -eq 0 ]
  is "$(cat "$alpha")" $'line one\nline two'
  is "$(cat "$NPX_STUB/calls")" "--yes skills add someone/skills#c1 -g -a universal -a claude-code -s alpha -s beta -y"
  is "$(jq -r '.skills.alpha | [.source, .commit] | join(" ")' "$lock")" "someone/skills c1"
  is "$(jq -r '.skills.alpha | .upstream_sha256 == .installed_sha256' "$lock")" true
  [[ "$output" == *"installed alpha"* ]]
}

@test "a second run installs nothing and leaves the lock file as it is" {
  "$kit/bin/wk" skills-sync
  before=$(cat "$lock")
  run "$kit/bin/wk" skills-sync
  [ "$status" -eq 0 ]
  is "$(installs)" 1
  is "$(cat "$lock")" "$before"
}

@test "a recorded patch is applied and the lock file holds the checksum before and after" {
  "$kit/bin/wk" skills-sync
  unpatched=$(jq -r '.skills.alpha.installed_sha256' "$lock")
  patch_alpha "line two" "line two, patched"
  run "$kit/bin/wk" skills-sync
  [ "$status" -eq 0 ]
  is "$(cat "$alpha")" $'line one\nline two, patched'
  is "$(ls "$HOME/.agents/skills/alpha")" "SKILL.md"
  is "$(jq -r '.skills.alpha.upstream_sha256' "$lock")" "$unpatched"
  [ "$(jq -r '.skills.alpha.installed_sha256' "$lock")" != "$unpatched" ]
  [[ "$output" == *"patched alpha"* ]]
}

@test "with a patch, a second run changes nothing" {
  patch_alpha "line two" "line two, patched"
  "$kit/bin/wk" skills-sync
  before=$(cat "$lock")
  "$kit/bin/wk" skills-sync
  is "$(installs)" 1
  is "$(cat "$alpha")" $'line one\nline two, patched'
  is "$(cat "$lock")" "$before"
}

@test "a patch that no longer applies fails and names the skill and the patch" {
  patch_alpha "a line upstream no longer has" "anything"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"alpha"*"patches/skills/alpha.patch no longer applies"* ]]
}

@test "a moved pin installs the skill again" {
  "$kit/bin/wk" skills-sync
  upstream skills#c2 alpha "newer text"
  upstream skills#c2 beta "beta text"
  echo "someone/skills#c2 alpha beta" > "$HOME/kit/skills.txt"
  "$kit/bin/wk" skills-sync
  is "$(cat "$alpha")" "newer text"
  is "$(jq -r '.skills.alpha.commit' "$lock")" c2
}

@test "a skill edited by hand is installed again" {
  "$kit/bin/wk" skills-sync
  echo "edited by hand" >> "$alpha"
  "$kit/bin/wk" skills-sync
  is "$(cat "$alpha")" $'line one\nline two'
}

@test "a skill the package does not hold fails and names it" {
  echo "someone/skills#c1 alpha gamma" > "$HOME/kit/skills.txt"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"no skill 'gamma'"* ]]
}

@test "a package without a pin fails and says how to pin it" {
  echo "someone/skills alpha" > "$HOME/kit/skills.txt"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"someone/skills has no pin"* ]]
}

@test "after a sync the doctor sees no difference; after a hand edit it reports one" {
  "$kit/bin/wk" skills-sync
  adopted_project
  "$kit/bin/wk" doctor > /dev/null
  is "$("$kit/bin/wk" doctor)" ""
  echo "edited by hand" >> "$alpha"
  run "$kit/bin/wk" doctor
  [[ "$output" == "skills: installed skills differ from skills.lock"* ]]
}
