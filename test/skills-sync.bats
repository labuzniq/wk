#!/usr/bin/env bats
# `wk skills-sync`: third-party skills are installed at a pinned commit, may carry a recorded patch, and the lock file records the result.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  c1=1111111111111111111111111111111111111111
  c2=2222222222222222222222222222222222222222
  upstream "skills#$c1" alpha $'line one\nline two'
  upstream "skills#$c1" beta "beta text"
  echo "someone/skills#$c1 alpha beta" > "$HOME/kit/skills.txt"
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
  is "$(cat "$NPX_STUB/calls")" "--yes skills@1.9.0 add someone/skills#$c1 -g -a universal -a claude-code -s alpha -s beta -y"
  is "$(jq -r '.skills.alpha | [.source, .commit] | join(" ")' "$lock")" "someone/skills $c1"
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
  is "$(jq -r '.skills.alpha.installed_sha256' "$lock")" "$(skills_sha256 alpha)"
  is "$(jq -r '.skills.alpha.patch_sha256' "$lock")" "$(shasum -a 256 < "$HOME/kit/patches/skills/alpha.patch" | cut -d' ' -f1)"
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
  [[ "$output" == *"skill alpha:"*"patches/skills/alpha.patch no longer applies"* ]]
}

@test "a patch that stops applying leaves the lock file as it was" {
  "$kit/bin/wk" skills-sync
  before=$(cat "$lock")
  patch_alpha "a line upstream no longer has" "anything"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  is "$(cat "$lock")" "$before"
}

@test "a patch whose line numbers are off still applies and leaves no backup file" {
  patch_alpha "line two" "line two, patched"
  sed -i '' 's/^@@ -1,2 +1,2 @@$/@@ -7,2 +7,2 @@/' "$HOME/kit/patches/skills/alpha.patch"
  upstream "skills#$c1" alpha $'intro\nline one\nline two'
  "$kit/bin/wk" skills-sync
  is "$(tail -1 "$alpha")" "line two, patched"
  is "$(ls "$HOME/.agents/skills/alpha")" "SKILL.md"
}

@test "a patch that reaches outside the skill folder is refused" {
  mkdir -p "$HOME/kit/patches/skills"
  printf -- '--- a/../beta/SKILL.md\n+++ b/../beta/SKILL.md\n@@ -1 +1 @@\n-beta text\n+changed\n' > "$HOME/kit/patches/skills/alpha.patch"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"alpha.patch names a path outside"* ]]
  is "$(cat "$HOME/.agents/skills/beta/SKILL.md")" "beta text"
}

@test "a changed patch installs the skill again with the new patch" {
  patch_alpha "line two" "line two, patched"
  "$kit/bin/wk" skills-sync
  patch_alpha "line two" "line two, patched again"
  "$kit/bin/wk" skills-sync
  is "$(installs)" 2
  is "$(tail -1 "$alpha")" "line two, patched again"
}

@test "a removed patch brings the upstream text back" {
  patch_alpha "line two" "line two, patched"
  "$kit/bin/wk" skills-sync
  rm "$HOME/kit/patches/skills/alpha.patch"
  "$kit/bin/wk" skills-sync
  is "$(tail -1 "$alpha")" "line two"
  is "$(jq -r '.skills.alpha | has("patch_sha256")' "$lock")" false
}

@test "a moved pin installs the skill again" {
  "$kit/bin/wk" skills-sync
  upstream "skills#$c2" alpha "newer text"
  upstream "skills#$c2" beta "beta text"
  echo "someone/skills#$c2 alpha beta" > "$HOME/kit/skills.txt"
  "$kit/bin/wk" skills-sync
  is "$(cat "$alpha")" "newer text"
  is "$(jq -r '.skills.alpha.commit' "$lock")" "$c2"
}

@test "a skill edited by hand is backed up, then installed again" {
  "$kit/bin/wk" skills-sync
  echo "edited by hand" >> "$alpha"
  run "$kit/bin/wk" skills-sync
  is "$(cat "$alpha")" $'line one\nline two'
  is "$(tail -1 "$HOME"/.claude/backup/*-skills/alpha/SKILL.md)" "edited by hand"
  [[ "$output" == *"backed up alpha to "* ]]
}

@test "a pin move makes no backup, because the old text can be installed again" {
  "$kit/bin/wk" skills-sync
  upstream "skills#$c2" alpha "newer text"
  upstream "skills#$c2" beta "beta text"
  echo "someone/skills#$c2 alpha beta" > "$HOME/kit/skills.txt"
  "$kit/bin/wk" skills-sync
  [ ! -e "$HOME/.claude/backup" ]
}

@test "upstream text that changed under the same commit stops the sync" {
  "$kit/bin/wk" skills-sync
  upstream "skills#$c1" alpha "rewritten under the same commit"
  rm -r "$HOME/.agents/skills/alpha"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"alpha"*"differs from the text skills.lock recorded"* ]]
}

@test "every file of a skill counts, and the doctor's checksum agrees with the lock file" {
  mkdir -p "$NPX_STUB/someone/skills#$c1/alpha/references/deep"
  echo "a" > "$NPX_STUB/someone/skills#$c1/alpha/references/a file.md"
  echo "b" > "$NPX_STUB/someone/skills#$c1/alpha/references/deep/b.md"
  touch "$NPX_STUB/someone/skills#$c1/alpha/.DS_Store"
  "$kit/bin/wk" skills-sync
  is "$(jq -r '.skills.alpha.installed_sha256' "$lock")" "$(skills_sha256 alpha)"
  is "$(jq -r '.installed_sha256' "$lock")" "$(skills_sha256 alpha beta)"
  before=$(skills_sha256 alpha)
  echo "edited" >> "$HOME/.agents/skills/alpha/references/deep/b.md"
  [ "$(skills_sha256 alpha)" != "$before" ]
}

@test "a skill dropped from skills.txt leaves the lock file, stays installed, and is named" {
  "$kit/bin/wk" skills-sync
  echo "someone/skills#$c1 alpha" > "$HOME/kit/skills.txt"
  run "$kit/bin/wk" skills-sync
  is "$(jq -r '.skills | keys | join(" ")' "$lock")" "alpha"
  is "$(jq -r '.installed_sha256' "$lock")" "$(skills_sha256 alpha)"
  [ -f "$HOME/.agents/skills/beta/SKILL.md" ]
  [[ "$output" == *"beta is no longer in skills.txt"* ]]
}

@test "a skill the package does not hold fails and names it, even when a folder of that name exists" {
  mkdir -p "$HOME/.agents/skills/gamma"
  echo "from somewhere else" > "$HOME/.agents/skills/gamma/SKILL.md"
  echo "someone/skills#$c1 alpha gamma" > "$HOME/kit/skills.txt"
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

@test "a pin that is a branch name, not a full commit, fails" {
  echo "someone/skills#main alpha" > "$HOME/kit/skills.txt"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"'main' is not a full commit"* ]]
}

@test "a skill name that is a path fails" {
  echo "someone/skills#$c1 ../alpha" > "$HOME/kit/skills.txt"
  run "$kit/bin/wk" skills-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"'../alpha' is not a skill name"* ]]
}

@test "a patch that was never applied is a doctor gap" {
  "$kit/bin/wk" skills-sync
  adopted_project
  "$kit/bin/wk" doctor > /dev/null
  patch_alpha "line two" "line two, patched"
  run "$kit/bin/wk" doctor
  [[ "$output" == "patches: patches/skills/alpha.patch is not applied"* ]]
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
