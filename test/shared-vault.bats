#!/usr/bin/env bats
# `wk shared-vault`: one vault outside any repo for lessons across projects; a commit with a project's private details fails.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  no_shared_vault
  config="$HOME/.config/workspace-kit/config.toml"
  vault="$HOME/.local/share/workspace-kit/shared-vault"
  mkdir -p "$HOME/projects/acme-shop"
  cd "$HOME" || return 1
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
  is "$(cd "$HOME/notes" && find . -path ./.git -prune -o -type f -print)" "./wiki/learnings.md"
  is "$(cat "$HOME/notes/wiki/learnings.md")" "# Mine"
  [ -d "$HOME/notes/.git" ]
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

@test "a project that is known only from its session queue is found too" {
  "$kit/bin/wk" shared-vault
  mkdir -p "$state/sessions/sideproject/queue" "$state/sessions/no-capture"
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
  mkdir "$HOME/projects/orca"
  lesson "Orca copies .worktreeinclude files."
  run "$kit/bin/wk" shared-vault check
  [ "$status" -eq 1 ]
  has "$output" ".allowed-words"
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
  is "$output" "shared_vault: no shared vault for lessons across projects; run \`wk shared-vault\`"
  run session_start "$project"
  has "$output" "Shared vault: none yet"
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
