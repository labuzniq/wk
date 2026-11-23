#!/usr/bin/env bats
# The doctor's gap lines: one line per missing piece, "<check_id>: <what is missing>".

load helpers

setup() {
  setup_home
  adopted_project
  "$kit/bin/wk" doctor > /dev/null # the first run reports the deferred vision once
}

# gaps: the check ids the doctor reports, in order, joined by spaces.
gaps() { "$kit/bin/wk" doctor | cut -d: -f1 | paste -sd' ' -; }

@test "a complete capsule has no gap" {
  [ "$(gaps)" = "" ]
}

@test "outside a git repo the doctor prints nothing" {
  cd "$HOME"
  run "$kit/bin/wk" doctor
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "a repo without a manifest gets one line that says to run wk adopt" {
  rm .workspace-kit.toml
  run "$kit/bin/wk" doctor
  [ "$output" = 'manifest: no .workspace-kit.toml; run `wk adopt`' ]
}

@test "a manifest without a slug is a gap" {
  sed -i '' '/^slug/d' .workspace-kit.toml
  [ "$(gaps)" = "manifest" ]
}

@test "a missing CLAUDE.md is a gap" {
  rm CLAUDE.md
  [ "$(gaps)" = "claude_md" ]
}

@test "a mise.toml without a setup task is a gap" {
  echo '[tools]' > mise.toml
  [ "$(gaps)" = "mise" ]
}

@test "a manifest without an Orca repo id is a gap" {
  sed -i '' '/^orca_repo_id/d' .workspace-kit.toml
  [ "$(gaps)" = "orca_repo" ]
}

@test "a missing .worktreeinclude is a gap" {
  rm .worktreeinclude
  [ "$(gaps)" = "orca_files" ]
}

@test "an orca.yaml without a setup script is a gap" {
  echo 'scripts: {}' > orca.yaml
  [ "$(gaps)" = "orca_setup_hook" ]
}

@test "enough commits without a vision is a gap that needs the user" {
  sed -i '' 's/^min_commits = .*/min_commits = 2/' .workspace-kit.toml
  run "$kit/bin/wk" doctor
  [[ "$output" == "vision: no vision yet; needs the user"* ]]
}

@test "a vision in STRATEGY.md counts as a vision" {
  sed -i '' 's/^min_commits = .*/min_commits = 2/' .workspace-kit.toml
  printf '# Strategy\n\n## Vision\n' > STRATEGY.md
  [ "$(gaps)" = "" ]
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
  [ "$(gaps)" = "matt_setup" ]
}

@test "a tracker doc of the old kind is a gap" {
  echo '# Issue tracker: Orca workspaces' > docs/agents/issue-tracker.md
  [ "$(gaps)" = "tracker" ]
}

@test "a vault without its overview page is a gap" {
  rm knowledge-base/wiki/overview.md
  [ "$(gaps)" = "vault_page" ]
}

@test "a skill Claude Code cannot see is a gap" {
  rm "$HOME/.claude/skills/setup-matt-pocock-skills"
  [ "$(gaps)" = "skills_visible" ]
}

@test "a machine with no shared skills folder has no skills gap" {
  rm -r "$HOME/.agents" "$HOME/.claude/skills"
  [ "$(gaps)" = "" ]
}

@test "an installed agent that differs from the lock file is a gap" {
  echo "edited" >> "$HOME/.claude/agents/ecc/reviewer.md"
  [ "$(gaps)" = "agents" ]
}

@test "a pending proposal is a gap that names the file" {
  touch knowledge-base/wiki/_proposals/2026-01-01-rule.md
  run "$kit/bin/wk" doctor
  [[ "$output" == "proposals: needs the user:"*"_proposals/2026-01-01-rule.md" ]]
}

@test "a check listed under [skip] is not reported" {
  rm CLAUDE.md
  echo 'claude_md = "no instructions wanted here"' >> .workspace-kit.toml
  [ "$(gaps)" = "" ]
}

@test "every gap is reported, one line each" {
  rm CLAUDE.md .worktreeinclude
  [ "$(gaps)" = "claude_md orca_files" ]
}
