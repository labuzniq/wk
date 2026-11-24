#!/usr/bin/env bats
# `wk kit-correction`: a correction seen in three projects is counted in the shared vault and offered to the kit as a pull request.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  shared="$HOME/shared-vault"
  records="$shared/wiki/corrections"
  mkdir -p "$records"
  # The installed kit is a repo with a local bare repo as its origin, and two pinned third-party texts.
  rm "$HOME/kit/templates"
  origin="$HOME/origin.git"
  git init -q --bare "$origin"
  git init -q "$HOME/kit"
  echo "someone/skills#abc123 alpha beta" > "$HOME/kit/skills.txt"
  printf '[source]\nrepo = "x"\ncommit = "y"\n\n[agents]\nreviewer = { skills = [] }\n' > "$HOME/kit/agents/agents.toml"
  mkdir -p "$HOME/kit/claude" "$HOME/kit/skills/wiki-ingest"
  echo "# Global instructions" > "$HOME/kit/claude/CLAUDE.md"
  echo "# wiki-ingest" > "$HOME/kit/skills/wiki-ingest/SKILL.md"
  git -C "$HOME/kit" add -A
  git -C "$HOME/kit" commit -q -m "chore: start"
  git -C "$HOME/kit" remote add origin "$origin"
  git -C "$HOME/kit" push -q -u origin main
}

# project <name>: an adopted project with a commit of its own, made on the first call; cds into it.
project() {
  if [ -d "$HOME/projects/$1" ]; then cd "$HOME/projects/$1" && return; fi
  new_repo "$HOME/projects/$1"
  printf 'slug = "%s"\ntype = "code"\nvault = "knowledge-base"\n\n[vision]\nmin_commits = 20\nrefresh_days = 90\n' "$1" > "$HOME/projects/$1/.workspace-kit.toml"
  cd "$HOME/projects/$1" || return 1
  git add .workspace-kit.toml
  git commit -q -m "chore: add workspace-kit capsule"
}

# record <key> [layer]: a shared correction record, without any project yet.
record() {
  printf -- '---\ntype: correction\nupdated: 2026-01-01\nlayer: %s\nsources:\n  - raw/sessions/2026-01-01-aaaa1111.md\n---\n# Use uv, not pip, in a Python project\n' \
    "${2:-check}" > "$records/$1.md"
}

# seen_in <key> <project>...: each project counts itself in the record.
seen_in() {
  local key="$1" name
  shift
  for name in "$@"; do
    project "$name"
    "$kit/bin/wk" kit-correction add "$key" > /dev/null
  done
}

corrections() { "$kit/bin/wk" kit-correction | tr '\t' ' '; }

# clone_with_fix <key> [path]: `start` clones the kit; the fix is one commit there that ends with the key's line. Sets $clone.
clone_with_fix() {
  local path="${2:-claude/CLAUDE.md}"
  clone=$("$kit/bin/wk" kit-correction start "$1" | sed -n 's/^cloned the kit into \([^ ]*\) .*/\1/p')
  mkdir -p "$clone/$(dirname "$path")"
  echo "- Use uv, not pip." >> "$clone/$path"
  git -C "$clone" add -A
  git -C "$clone" commit -q -m "fix: use uv, not pip" -m "The check goes red on pip install." -m "Correction: $1"
  cd "$clone" || return 1
}

@test "no shared record: nothing is printed" {
  run "$kit/bin/wk" kit-correction
  [ "$status" -eq 0 ]
  is "$output" ""
}

@test "a correction seen in two projects is waiting, and the same project counts once" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-one
  is "$(corrections)" "waiting uv-not-pip 2 check -"
}

@test "a correction seen in three projects is due" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  is "$(corrections)" "due uv-not-pip 3 check -"
}

@test "adding a project prints what it did, and a second run keeps it" {
  record uv-not-pip
  project zeta-one
  run "$kit/bin/wk" kit-correction add uv-not-pip
  [ "$status" -eq 0 ]
  has "$output" "added this project to $records/uv-not-pip.md; it is seen in 1 project"
  before=$(cat "$records/uv-not-pip.md")
  run "$kit/bin/wk" kit-correction add uv-not-pip
  has "$output" "kept"
  is "$(cat "$records/uv-not-pip.md")" "$before"
}

@test "the record names no project, so the shared vault's private-details check still passes" {
  record uv-not-pip
  seen_in uv-not-pip acme-shop secret-client billing-api
  lacks "$(cat "$records/uv-not-pip.md")" "acme"
  lacks "$(cat "$records/uv-not-pip.md")" "$HOME"
  cd "$HOME"
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 0 ]
  is "$output" ""
}

@test "a clone of the same project counts as the same project" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one
  git clone -q "$HOME/projects/zeta-one" "$HOME/projects/zeta-one-copy"
  cd "$HOME/projects/zeta-one-copy"
  run "$kit/bin/wk" kit-correction add uv-not-pip
  has "$output" "kept"
}

@test "adding to a record that does not exist fails and says how to write it" {
  project zeta-one
  run "$kit/bin/wk" kit-correction add uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "no shared record $records/uv-not-pip.md"
  has "$output" "corrections.md"
}

@test "adding outside a project fails" {
  record uv-not-pip
  cd "$HOME"
  run "$kit/bin/wk" kit-correction add uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "run it inside a project"
}

@test "a record without projects, with a bad project id, or with a bad layer is broken" {
  record no-projects
  record bad-id
  printf 'projects:\n  - acme-shop\n' > "$HOME/frag"
  sed -i '' '/^sources:/{
r '"$HOME/frag"'
}' "$records/bad-id.md"
  record bad-layer hook
  seen_in bad-layer zeta-one
  run corrections
  has "$output" "broken bad-id 0 check acme-shop is not a project id"
  has "$output" "broken bad-layer 1 hook layer must be design, check, proof or prose"
  has "$output" "broken no-projects 0 check the frontmatter lists no project"
}

@test "the doctor shows a due correction in every project, and a waiting one nowhere" {
  record uv-not-pip
  record waits
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  seen_in waits zeta-one
  project zeta-four
  run "$kit/bin/wk" doctor
  has "$output" "kit-correction-uv-not-pip: seen in 3 projects (cheapest layer: check); offer the fix to the kit the way \`kit-correction.md\` in the \`project-setup\` skill says. Record: $records/uv-not-pip.md"
  lacks "$output" "kit-correction-waits"
}

@test "start refuses a correction that is not due" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two
  run "$kit/bin/wk" kit-correction start uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "'uv-not-pip' is waiting, not due"
}

@test "start clones the kit on a branch of its own and leaves the installed kit as it is" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  before=$(git -C "$HOME/kit" status --porcelain; git -C "$HOME/kit" rev-parse HEAD; git -C "$HOME/kit" branch --show-current)
  clone_with_fix uv-not-pip
  is "$(git -C "$clone" branch --show-current)" "correction/uv-not-pip"
  is "$(git -C "$clone" remote get-url origin)" "$origin"
  is "$(git -C "$HOME/kit" status --porcelain; git -C "$HOME/kit" rev-parse HEAD; git -C "$HOME/kit" branch --show-current)" "$before"
}

@test "offer pushes the one commit and opens a pull request, reported in one line with the way to undo it" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 0 ]
  url=https://github.com/test/kit/pull/1
  is "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" 1
  is "$output" "kit-correction: offered $url for 'uv-not-pip', one commit ($(git rev-parse --short HEAD)); to undo it, close the pull request, or after the merge run \`gh pr revert $url\`"
  is "$(git -C "$origin" rev-parse correction/uv-not-pip)" "$(git rev-parse HEAD)"
  is "$(git -C "$origin" rev-list --count main..correction/uv-not-pip)" 1
  grep -qx -- "pr create --base main --head correction/uv-not-pip --title fix: use uv, not pip --body-file .*" "$GH_STUB/calls"
  body=$(cat "$GH_STUB/pr-body.md")
  has "$body" "seen in 3 projects"
  has "$body" "Use uv, not pip, in a Python project"
  has "$body" "The check goes red on pip install."
  has "$body" "gh pr revert"
  is "$(corrections)" "offered uv-not-pip 3 check $url"
}

@test "an offered correction leaves the doctor, and a second offer changes nothing" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip
  "$kit/bin/wk" kit-correction offer uv-not-pip > /dev/null
  calls=$(cat "$GH_STUB/calls")
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 0 ]
  has "$output" "was offered before as https://github.com/test/kit/pull/1; nothing to do"
  is "$(cat "$GH_STUB/calls")" "$calls"
  cd "$HOME/projects/zeta-one"
  lacks "$("$kit/bin/wk" doctor)" "kit-correction-uv-not-pip"
}

@test "a merged fix in the kit's history makes the correction done" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  git -C "$HOME/kit" commit -q --allow-empty -m "fix: use uv (#9)" -m "Correction: uv-not-pip"
  is "$(corrections)" "done uv-not-pip 3 check $(git -C "$HOME/kit" rev-parse --short HEAD)"
}

@test "offer refuses two commits, and pushes nothing" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip
  git commit -q --allow-empty -m "fix: more"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "holds 2 commits over origin/main; the fix is one commit of its own"
  is "$(git -C "$origin" branch --list 'correction/*')" ""
  lacks "$(cat "$GH_STUB/calls")" "pr create"
}

@test "offer refuses a commit without the key's line" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip
  git commit -q --amend -m "fix: use uv, not pip"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "the last line of the commit message must be \`Correction: uv-not-pip\`"
}

@test "offer refuses a copy of a third-party skill's or agent's text and names the recorded patch instead" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip skills/beta/SKILL.md
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "skills/beta/SKILL.md is text of the third-party skill 'beta'"
  has "$output" "patches/skills/beta.patch"
  git reset -q --hard origin/main
  echo "agent" > agents/reviewer.md
  git add -A
  git commit -q -m "fix: reviewer" -m "Correction: uv-not-pip"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "agents/reviewer.md is text of the third-party agent 'reviewer'"
  has "$output" "patches/agents/reviewer.patch"
  lacks "$(cat "$GH_STUB/calls")" "pr create"
}

@test "a recorded patch for a third-party skill and an edit of a kit skill are offered" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip patches/skills/beta.patch
  echo "- step" >> skills/wiki-ingest/SKILL.md
  git add -A
  git commit -q --amend --no-edit
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 0 ]
  has "$output" "kit-correction: offered"
}

@test "offer refuses a folder that is not a clone of the kit" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  cd "$HOME/projects/zeta-one"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "is not a clone of the kit"
}

@test "a failed pull request can be offered again from the same clone" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip
  touch "$GH_STUB/fail-create"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -ne 0 ]
  rm "$GH_STUB/fail-create"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 0 ]
  has "$output" "kit-correction: offered"
}

@test "a pull request opened from another Mac, or closed, counts as offered and nothing is pushed" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  clone_with_fix uv-not-pip
  echo '[{"url": "https://github.com/test/kit/pull/4", "state": "CLOSED", "headRefName": "correction/uv-not-pip"}]' > "$GH_STUB/prs.json"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 0 ]
  is "$output" "kit-correction: 'uv-not-pip' was offered before as https://github.com/test/kit/pull/4; nothing to do"
  is "$(git -C "$origin" branch --list 'correction/*')" ""
  lacks "$(cat "$GH_STUB/calls")" "pr create"
  is "$(corrections)" "offered uv-not-pip 3 check https://github.com/test/kit/pull/4"
}

@test "a fix only on a branch of the installed kit, such as a closed pull request's, is not done" {
  record uv-not-pip
  seen_in uv-not-pip zeta-one zeta-two zeta-three
  git -C "$HOME/kit" switch -q -c correction/uv-not-pip
  git -C "$HOME/kit" commit -q --allow-empty -m "fix: use uv" -m "Correction: uv-not-pip"
  git -C "$HOME/kit" switch -q main
  is "$(corrections)" "due uv-not-pip 3 check -"
}

@test "a commit that names a project is refused before anything reaches GitHub" {
  record uv-not-pip
  seen_in uv-not-pip acme-shop zeta-two zeta-three
  clone_with_fix uv-not-pip
  git commit -q --amend -m "fix: use uv, not pip" -m "Seen in acme-shop at $HOME/projects/acme-shop." -m "Correction: uv-not-pip"
  run "$kit/bin/wk" kit-correction offer uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "names a project's private details"
  has "$output" "commit.txt:3: names the project 'acme-shop'"
  has "$output" "holds a path in the home folder"
  is "$(git -C "$origin" branch --list 'correction/*')" ""
  lacks "$(cat "$GH_STUB/calls")" "pr create"
}

@test "a record without frontmatter is not reported as added" {
  printf '# Use uv, not pip\n' > "$records/uv-not-pip.md"
  project zeta-one
  run "$kit/bin/wk" kit-correction add uv-not-pip
  [ "$status" -eq 1 ]
  has "$output" "could not add this project"
}
