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

@test "a repo this person has not set up in their Orca is a gap" {
  rm -r "$state/repos"
  is "$(gaps)" "orca_repo"
}

@test "global instructions that do not import the kit's shared part are a gap" {
  echo "my own rules" > "$HOME/.claude/CLAUDE.md"
  is "$(gaps)" "instructions"
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

@test "a check listed under [skip] is not reported" {
  rm CLAUDE.md
  echo 'claude_md = "no instructions wanted here"' >> .workspace-kit.toml
  is "$(gaps)" ""
}

@test "every gap is reported, one line each" {
  rm CLAUDE.md .worktreeinclude
  is "$(gaps)" "claude_md orca_files"
}

# old_python_project: a Python project whose mise.toml was written before the starter checks existed.
old_python_project() {
  echo '[project]' > pyproject.toml
  sed -i '' 's/^stack = .*/stack = ["python"]/' .workspace-kit.toml
  printf '\n[tasks.lint]\nrun = ["uv run ruff check"]\n' >> mise.toml
}

@test "a project adopted before the starter checks is offered them" {
  old_python_project
  run "$kit/bin/wk" doctor
  is "$output" 'starter_checks: the lint task does not run the starter checks for python (a small lint set for the first mistakes a coding agent makes); run `wk adopt`, then add the command it prints to the lint task in mise.toml'
}

@test "starter checks that exist but are not in the lint task are a gap, until the printed command is added" {
  old_python_project
  command=$("$kit/libexec/wk-adopt" | sed -n 's/.*add this command to the run list of \[tasks.lint\]: //p')
  is "$(gaps)" "starter_checks"
  sed -i '' "s~^run = \[\"uv run ruff check\"\]~run = [\"uv run ruff check\", \"$command\"]~" mise.toml
  is "$(gaps)" ""
  run "$kit/libexec/wk-adopt"
  [[ "$output" != *"does not run the starter checks"* ]]
}

@test "a lint task that names starter checks whose files are gone is a gap" {
  old_python_project
  echo 'run = ["ruff check --config checks/starter/python.toml"]' >> mise.toml
  is "$(gaps)" "starter_checks"
}

@test "a stack the kit has no starter checks for is no gap" {
  sed -i '' 's/^stack = .*/stack = ["rust"]/' .workspace-kit.toml
  is "$(gaps)" ""
}

@test "the starter checks can be skipped with a reason" {
  old_python_project
  echo 'starter_checks = "this project lints in CI only"' >> .workspace-kit.toml
  is "$(gaps)" ""
}

@test "a project adopted as an empty folder is offered the starter checks once it has a stack" {
  echo '{}' > package.json
  is "$(gaps)" "starter_checks"
  "$kit/libexec/wk-adopt" > /dev/null
  [ -f checks/starter/ts.json ]
}
