#!/usr/bin/env bats
# The doctor's gap lines: one line per missing piece, "<check_id>: <what is missing>".

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  adopted_project
  "$kit/bin/wk" doctor > /dev/null # the first run reports the deferred vision once
}

# gaps: the check ids the doctor reports, in order, joined by spaces.
gaps() {
  local lines
  lines=$("$kit/bin/wk" doctor) || { echo "doctor exited with $?"; return; }
  printf '%s' "$lines" | cut -d: -f1 | paste -sd' ' -
}

@test "a complete capsule has no gap" {
  is "$(gaps)" ""
}

@test "outside a git repo the doctor prints nothing" {
  cd "$HOME"
  run "$kit/bin/wk" doctor
  [ "$status" -eq 0 ]
  is "$output" ""
}

@test "a repo without a manifest gets one line that says to run wk adopt" {
  rm .workspace-kit.toml
  run "$kit/bin/wk" doctor
  is "$output" 'manifest: no .workspace-kit.toml; run `wk adopt`'
}

@test "a manifest without a slug is a gap" {
  sed -i '' '/^slug/d' .workspace-kit.toml
  is "$(gaps)" "manifest"
}

@test "a manifest without a type is a gap" {
  sed -i '' '/^type/d' .workspace-kit.toml
  is "$(gaps)" "manifest"
}

@test "a missing CLAUDE.md is a gap" {
  rm CLAUDE.md
  is "$(gaps)" "claude_md"
}

@test "a mise.toml without a setup task is a gap" {
  echo '[tools]' > mise.toml
  is "$(gaps)" "mise"
}

@test "a manifest without an Orca repo id is a gap" {
  sed -i '' '/^orca_repo_id/d' .workspace-kit.toml
  is "$(gaps)" "orca_repo"
}

@test "a missing .worktreeinclude is a gap" {
  rm .worktreeinclude
  is "$(gaps)" "orca_files"
}

@test "a missing orca.yaml is a gap" {
  rm orca.yaml
  is "$(gaps)" "orca_files orca_setup_hook"
}

@test "an orca.yaml without a setup script is a gap" {
  echo 'scripts: {}' > orca.yaml
  is "$(gaps)" "orca_setup_hook"
}

@test "enough commits without a vision is a gap that needs the user" {
  sed -i '' 's/^min_commits = .*/min_commits = 2/' .workspace-kit.toml
  run "$kit/bin/wk" doctor
  [[ "$output" == "vision: no vision yet; needs the user"* ]]
}

@test "a vision in STRATEGY.md counts as a vision" {
  sed -i '' 's/^min_commits = .*/min_commits = 2/' .workspace-kit.toml
  printf '# Strategy\n\n## Vision\n' > STRATEGY.md
  is "$(gaps)" ""
}

@test "a fresh vision is no gap" {
  sed -i '' 's/^min_commits = .*/min_commits = 2/' .workspace-kit.toml
  echo '# Vision' > VISION.md
  git add VISION.md
  git commit -q -m "docs: vision"
  is "$(gaps)" ""
}

@test "a vision older than refresh_days is a gap that needs the user" {
  echo '# Vision' > VISION.md
  git add VISION.md
  GIT_COMMITTER_DATE="2020-01-01T00:00:00Z" git commit -q -m "docs: vision"
  run "$kit/bin/wk" doctor
  [[ "$output" == "vision_fresh: VISION.md is older than 90 days; needs the user"* ]]
}

@test "a missing tracker doc is a gap" {
  rm docs/agents/issue-tracker.md
  is "$(gaps)" "matt_setup"
}

@test "a tracker doc of the old kind is a gap" {
  echo '# Issue tracker: Orca workspaces' > docs/agents/issue-tracker.md
  is "$(gaps)" "tracker"
}

@test "a vault without its overview page is a gap" {
  rm knowledge-base/wiki/overview.md
  is "$(gaps)" "vault_page"
}

@test "a skill Claude Code cannot see is a gap" {
  rm "$HOME/.claude/skills/setup-matt-pocock-skills"
  is "$(gaps)" "skills_visible"
}

@test "a machine with no shared skills folder reports the locked skills, not a skill named *" {
  rm -r "$HOME/.agents" "$HOME/.claude/skills"
  is "$(gaps)" "skills"
}

@test "an installed skill that differs from the lock file is a gap" {
  echo "edited" >> "$HOME/.agents/skills/setup-matt-pocock-skills/SKILL.md"
  is "$(gaps)" "skills"
}

@test "a missing skills.lock is a gap, and the other checks still run" {
  rm "$HOME/kit/skills.lock" CLAUDE.md
  is "$(gaps)" "claude_md skills"
}

@test "an installed agent that differs from the lock file is a gap" {
  echo "edited" >> "$HOME/.claude/agents/ecc/reviewer.md"
  is "$(gaps)" "agents"
}

@test "a pending proposal is a gap that names the file" {
  touch knowledge-base/wiki/_proposals/2026-01-01-rule.md
  run "$kit/bin/wk" doctor
  [[ "$output" == "proposals: needs the user:"*"_proposals/2026-01-01-rule.md" ]]
}

@test "several pending proposals stay on one line" {
  touch knowledge-base/wiki/_proposals/a.md knowledge-base/wiki/_proposals/b.md
  run "$kit/bin/wk" doctor
  is "${#lines[@]}" 1
  [[ "$output" == *"_proposals/a.md "*"_proposals/b.md" ]]
}

# correction <key> <layer> <count>: a correction record in the vault, seen in that many sessions.
correction() {
  local n
  mkdir -p knowledge-base/wiki/corrections
  {
    printf -- '---\ntype: correction\nupdated: 2026-01-01\nlayer: %s\nsources:\n' "$2"
    for n in $(seq "$3"); do
      touch "knowledge-base/raw/sessions/s$n.md"
      printf '  - raw/sessions/s%s.md\n' "$n"
    done
    printf -- '---\n# %s\n' "$1"
  } > "knowledge-base/wiki/corrections/$1.md"
}

@test "a correction seen in three sessions is a gap the agent fixes itself, and the line names the record" {
  correction uv-not-pip check 3
  run "$kit/bin/wk" doctor
  [[ "$output" == "correction-uv-not-pip: corrected in 3 sessions (cheapest layer: check); "*"wiki/corrections/uv-not-pip.md"* ]]
  [[ "$output" != *"needs the user"* ]]
}

@test "a due correction that needs a design change is a gap that needs the user" {
  correction one-config-file design 3
  run "$kit/bin/wk" doctor
  [[ "$output" == "correction-one-config-file: corrected in 3 sessions (cheapest layer: design); needs the user"* ]]
}

@test "a correction corrected again after its check is a gap that names the commit" {
  mkdir -p knowledge-base/wiki/corrections
  for name in 2026-01-01-demo-aaaa1111 2026-01-02-demo-bbbb2222 2026-01-09-demo-cccc3333; do
    touch "knowledge-base/raw/sessions/$name.md"
  done
  printf -- '---\nlayer: check\nsources:\n  - raw/sessions/2026-01-01-demo-aaaa1111.md\n  - raw/sessions/2026-01-02-demo-bbbb2222.md\n  - raw/sessions/2026-01-09-demo-cccc3333.md\n---\n' \
    > knowledge-base/wiki/corrections/uv-not-pip.md
  GIT_COMMITTER_DATE="2026-01-04T12:00:00Z" git commit -q --allow-empty -m "test: uv, not pip" -m "Correction: uv-not-pip"
  run "$kit/bin/wk" doctor
  [[ "$output" == "correction-uv-not-pip: corrected again after $(git rev-parse --short HEAD), "*"make the check catch it"* ]]
}

@test "a correction seen in two sessions is no gap" {
  correction uv-not-pip check 2
  is "$(gaps)" ""
}

@test "a correction whose check is committed is no gap" {
  correction uv-not-pip check 3
  git commit -q --allow-empty -m "test: uv, not pip" -m "Correction: uv-not-pip"
  is "$(gaps)" ""
}

@test "a correction the user skipped is not reported, the others are" {
  correction uv-not-pip check 3
  correction tabs prose 4
  echo 'correction-uv-not-pip = "pip is fine here"' >> .workspace-kit.toml
  is "$(gaps)" "correction-tabs"
}

@test "a broken correction record is a gap that says how to fix it" {
  correction uv-not-pip hook 1
  run "$kit/bin/wk" doctor
  [[ "$output" == "correction-uv-not-pip: the record "*"is broken: layer must be design, check, proof or prose"* ]]
}

@test "a check listed under [skip] is not reported" {
  rm CLAUDE.md
  echo 'claude_md = "no instructions wanted here"' >> .workspace-kit.toml
  is "$(gaps)" ""
}

@test "every gap is reported, one line each" {
  rm CLAUDE.md .worktreeinclude
  is "$(gaps)" "claude_md orca_files"
}
