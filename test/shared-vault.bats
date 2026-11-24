#!/usr/bin/env bats
# `wk shared-vault`: one vault outside any repo for lessons across projects; a commit with a project's private details fails.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  no_shared_vault
  config="$HOME/.config/workspace-kit/config.toml"
  vault="$HOME/.local/share/workspace-kit/shared-vault"
  adopted "$HOME/projects/acme-shop"
  cd "$HOME" || return 1
}

# adopted <folder>: a project folder with a capsule manifest, which is how the check knows a project.
adopted() {
  mkdir -p "$1"
  printf 'slug = "%s"\n' "$(basename "$1")" > "$1/.workspace-kit.toml"
}

# Every file of the vault and of the home's settings, with its checksum, plus what Orca was asked to keep.
snapshot() {
  find "$vault" "$HOME/.claude" "$config" -type f -exec shasum {} + | sort
  git -C "$vault" rev-parse HEAD
  cat "$ORCA_STUB/repos.json" "$ORCA_STUB/automations.json"
}

# lesson <text>: a page of the shared vault with that text, staged for a commit.
lesson() {
  printf '%s\n' "$1" > "$vault/wiki/howto/lesson.md"
  git -C "$vault" add -A .
}

# session_start <folder>: what the session-start hook adds to a session opened in the folder.
session_start() {
  touch "$ORCA_STUB/down" # the hook's background board sync then stops at once
  jq -n --arg cwd "$1" '{cwd: $cwd}' | "$kit/hooks/session-start.sh"
}

@test "the first run creates the vault as its own git repo, outside any repo" {
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 0 ]
  has "$output" "created $vault"
  grep -qx "shared_vault = \"$vault\"" "$config"
  for file in CLAUDE.md index.md log.md wiki/overview.md wiki/learnings.md raw/sessions/.gitkeep; do
    [ -f "$vault/$file" ] || { echo "missing: $file"; return 1; }
  done
  is "$(head -1 "$vault/CLAUDE.md")" "# Shared vault schema"
  is "$(grep -rl "__DATE__" "$vault/wiki")" ""
  is "$(git -C "$vault" rev-parse --show-toplevel)" "$vault"
  is "$(git -C "$vault" status --porcelain)" ""
  is "$(git -C "$vault" rev-list --count HEAD)" 1
}

@test "every session may read and write the vault, and it is linted on a schedule" {
  echo '{"permissions": {"additionalDirectories": ["/elsewhere"], "defaultMode": "plan"}}' > "$HOME/.claude/settings.json"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 0 ]
  is "$(jq -c '.permissions' "$HOME/.claude/settings.json")" "{\"additionalDirectories\":[\"/elsewhere\",\"$vault\"],\"defaultMode\":\"plan\"}"
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json")" "Wiki lint: shared"
  grep -qx -- "automations create --name Wiki lint: shared --trigger 0 10 \* \* 6 --prompt Run the wiki-lint skill, then stop. --provider claude --workspace path:$vault --fresh-session --enabled --json" "$ORCA_STUB/calls"
  is "$(jq -r '.[].path' "$ORCA_STUB/repos.json")" "$vault"
}

@test "a second run changes nothing and keeps what was learned" {
  "$kit/bin/wk" shared-vault
  lesson "Orca copies files named in .worktreeinclude into a new worktree."
  git -C "$vault" commit -q -m "docs(wiki): ingest"
  before=$(snapshot)
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 0 ]
  is "$(snapshot)" "$before"
  is "$output" "kept    $vault"
}

@test "a vault the owner already has is kept as it is" {
  mkdir -p "$HOME/notes/wiki"
  echo "# Mine" > "$HOME/notes/wiki/learnings.md"
  echo "shared_vault = \"$HOME/notes\"" >> "$config"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 0 ]
  has "$output" "kept    $HOME/notes"
  has "$output" "added the missing vault files"
  is "$(cat "$HOME/notes/wiki/learnings.md")" "# Mine"
  is "$(head -1 "$HOME/notes/CLAUDE.md")" "# Shared vault schema"
  [ -d "$HOME/notes/.git" ]
  is "$("$kit/bin/wk" shared-vault 2>&1)" "kept    $HOME/notes"
}

@test "the owner's own pre-commit hook in a kept vault is moved aside, not lost" {
  new_repo "$HOME/notes"
  echo "# Mine" > "$HOME/notes/CLAUDE.md"
  printf '#!/bin/sh\necho mine\n' > "$HOME/notes/.git/hooks/pre-commit"
  echo "shared_vault = \"$HOME/notes\"" >> "$config"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 0 ]
  has "$output" "moved your pre-commit hook to $HOME/notes/.git/hooks/pre-commit.before-wk"
  is "$(tail -1 "$HOME/notes/.git/hooks/pre-commit.before-wk")" "echo mine"
  is "$(cat "$HOME/notes/CLAUDE.md")" "# Mine"
}

@test "a global hooks folder does not switch the check off" {
  git config --global core.hooksPath "$HOME/global-hooks"
  "$kit/bin/wk" shared-vault
  [ ! -e "$HOME/global-hooks" ]
  lesson "In acme-shop the setup failed."
  run git -C "$vault" commit -m "docs(wiki): ingest"
  [ "$status" -ne 0 ]
  has "$output" "names the project 'acme-shop'"
}

@test "with Orca closed the vault is made, the run fails with the reason, and the doctor keeps the gap until a run with Orca" {
  adopted_project
  touch "$ORCA_STUB/down"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 75 ]
  has "$output" "created $vault"
  has "$output" "Orca did not answer"
  "$kit/bin/wk" doctor > /dev/null # the first run reports the deferred vision once
  is "$("$kit/bin/wk" doctor | cut -d: -f1)" "shared_vault"
  rm "$ORCA_STUB/down"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 0 ]
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json" | grep shared)" "Wiki lint: shared"
  is "$("$kit/bin/wk" doctor)" ""
}

@test "a vault moved to another place names the automation that still runs in the old one" {
  "$kit/bin/wk" shared-vault
  sed -i '' "s|^shared_vault = .*|shared_vault = \"$HOME/elsewhere\"|" "$config"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 1 ]
  has "$output" "the automation 'Wiki lint: shared' still runs in $vault"
}

@test "a path that is not written in full is refused" {
  echo 'shared_vault = "~/notes"' >> "$config"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 1 ]
  has "$output" "write it as a full path"
  [ ! -e "$HOME/~" ]
}

@test "a config file without a last line break stays readable" {
  printf 'projects_root = "%s"\nkit = "%s"' "$HOME/projects" "$HOME/kit" > "$config"
  "$kit/bin/wk" shared-vault
  is "$(sed -n 's/^kit = "\(.*\)"$/\1/p' "$config")" "$HOME/kit"
  is "$("$kit/bin/wk" shared-vault path)" "$vault"
}

@test "a vault behind a link is still known to session start" {
  mkdir "$HOME/real"
  ln -s "$HOME/real" "$HOME/link"
  echo "shared_vault = \"$HOME/link/vault\"" >> "$config"
  "$kit/bin/wk" shared-vault
  is "$("$kit/bin/wk" shared-vault path)" "$HOME/real/vault"
  run session_start "$HOME/real/vault"
  is "${output%%:*}" "Shared vault"
}

@test "a place inside a repo is refused" {
  new_repo "$HOME/projects/acme-shop"
  echo "shared_vault = \"$HOME/projects/acme-shop/lessons\"" >> "$config"
  run "$kit/bin/wk" shared-vault
  [ "$status" -eq 1 ]
  has "$output" "is inside the git repo $HOME/projects/acme-shop"
  [ ! -e "$HOME/projects/acme-shop/lessons" ]
}

@test "path prints where the vault is, and says so when there is none" {
  run "$kit/bin/wk" shared-vault path
  [ "$status" -eq 1 ]
  has "$output" "no shared vault yet; run \`wk shared-vault\`"
  "$kit/bin/wk" shared-vault
  is "$("$kit/bin/wk" shared-vault path)" "$vault"
}

@test "a lesson about a tool passes the check and can be committed" {
  "$kit/bin/wk" shared-vault
  lesson "In a project, Orca starts a new card as in-progress. See ~/.claude/settings.json and the kit's wk doctor."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 0 ]
  is "$output" ""
  git -C "$vault" commit -q -m "docs(wiki): ingest"
}

@test "a project's name is found, and the commit fails" {
  "$kit/bin/wk" shared-vault
  lesson $'Orca is fine.\nIn Acme-Shop the setup script failed.'
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  has "$output" "wiki/howto/lesson.md:2: names the project 'acme-shop'"
  has "$output" "Reword each line"
  run git -C "$vault" commit -m "docs(wiki): ingest"
  [ "$status" -ne 0 ]
  is "$(git -C "$vault" rev-list --count HEAD)" 1
}

@test "with no project at all the check passes" {
  rm -rf "$HOME/projects/acme-shop"
  "$kit/bin/wk" shared-vault
  lesson "Orca is fine."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 0 ]
  is "$output" ""
}

@test "a folder that only groups projects is not a project name, a project inside it is" {
  "$kit/bin/wk" shared-vault
  adopted "$HOME/projects/work/Big-Co"
  lesson $'The setup script did not work at first.\nFor big-co the hook was slow.'
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  is "$(printf '%s\n' "$output" | head -1)" "wiki/howto/lesson.md:2: names the project 'Big-Co'"
  lacks "$output" "lesson.md:1"
}

@test "a project name with characters that mean something to sed is reported as it is" {
  "$kit/bin/wk" shared-vault
  adopted "$HOME/projects/r&d|lab"
  lesson "The r&d|lab repo broke."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  has "$output" "lesson.md:1: names the project 'r&d|lab'"
}

@test "a project that is known only from its session queue is found too" {
  "$kit/bin/wk" shared-vault
  mkdir -p "$state/sessions/sideproject/queue" "$state/sessions/no-capture/queue-like"
  lesson "The hook of sideproject was slow; no-capture is a folder of the kit."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  has "$output" "lesson.md:1: names the project 'sideproject'"
  lacks "$output" "'no-capture'"
}

@test "a path written out in the home folder is found" {
  "$kit/bin/wk" shared-vault
  lesson "Settings live in $HOME/.claude/settings.json."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  has "$output" "wiki/howto/lesson.md:1: holds a path in the home folder"
}

@test "a word the owner allowed is not a private detail" {
  "$kit/bin/wk" shared-vault
  adopted "$HOME/projects/orca"
  lesson "Orca copies .worktreeinclude files."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  has "$output" "goes to the project's vault instead"
  echo "orca" > "$vault/.allowed-words"
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 0 ]
}

@test "session start names the project vault and the shared vault" {
  "$kit/bin/wk" shared-vault
  adopted_project
  run session_start "$project"
  [ "$status" -eq 0 ]
  has "$output" "Vault: $project/knowledge-base "
  has "$output" "Shared vault: $vault "
  lacks "$output" "shared_vault:"
}

@test "a session in the shared vault is not asked to set up a capsule" {
  "$kit/bin/wk" shared-vault
  run session_start "$vault"
  [ "$status" -eq 0 ]
  is "${output%%:*}" "Shared vault"
  lacks "$output" "wk adopt"
}

@test "without a shared vault the doctor names the command that creates it" {
  adopted_project
  "$kit/bin/wk" doctor > /dev/null # the first run reports the deferred vision once
  run "$kit/bin/wk" doctor
  has "$output" "shared_vault: the shared vault for lessons across projects, or its lint automation, is not set up; run \`wk shared-vault\`"
  run session_start "$project"
  has "$output" "Shared vault: none yet"
  rm "$ORCA_STUB/down"
  "$kit/bin/wk" shared-vault
  is "$("$kit/bin/wk" doctor)" ""
}

@test "every wk command the kit's skills name exists" {
  while read -r command; do
    [ -x "$kit/libexec/wk-$command" ] || { echo "skills name \`wk $command\`, which does not exist"; return 1; }
  done < <(grep -oh '`wk [a-z-]*' "$kit"/skills/*/SKILL.md | cut -d' ' -f2 | sort -u)
  "$kit/bin/wk" shared-vault
  grep -q "Anonymous by rule" "$vault/CLAUDE.md"
}
