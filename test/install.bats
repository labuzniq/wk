#!/usr/bin/env bats
# `install.sh` in a throwaway home: the kit is a folder of links to this checkout, with no third-party skill and one local agent.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  no_shared_vault
  for part in install.sh bin libexec lib claude hooks skills docs; do ln -s "$kit/$part" "$HOME/kit/$part"; done
  : > "$HOME/kit/skills.txt"
  new_repo "$HOME/upstream"
  mkdir "$HOME/upstream/agents"
  printf -- '---\nname: reviewer\n---\nReview the code.\n' > "$HOME/upstream/agents/reviewer.md"
  git -C "$HOME/upstream" add -A
  git -C "$HOME/upstream" commit -q -m "feat: reviewer"
  printf '[source]\nrepo = "%s"\ncommit = "%s"\n\n[agents]\nreviewer = { skills = [] }\n' \
    "$HOME/upstream" "$(git -C "$HOME/upstream" rev-parse HEAD)" > "$HOME/kit/agents/agents.toml"
  echo '{}' > "$HOME/.claude/settings.json"
  vault="$HOME/.local/share/workspace-kit/shared-vault"
  cd "$HOME" || return 1
}

@test "the installer creates the shared vault" {
  run "$HOME/kit/install.sh"
  [ "$status" -eq 0 ]
  has "$output" "created $vault"
  [ -f "$vault/wiki/learnings.md" ]
  is "$(jq -r '.permissions.additionalDirectories[]' "$HOME/.claude/settings.json")" "$vault"
  is "$(jq -r '.[].name' "$ORCA_STUB/automations.json")" "Wiki lint: shared"
}

@test "a second install keeps the shared vault and what is in it" {
  "$HOME/kit/install.sh"
  echo "A lesson." >> "$vault/wiki/learnings.md"
  before=$(find "$vault" -path "$vault/.git" -prune -o -type f -exec shasum {} + | sort; cat "$HOME/.claude/settings.json" "$ORCA_STUB/automations.json")
  run "$HOME/kit/install.sh"
  [ "$status" -eq 0 ]
  has "$output" "kept    $vault"
  lacks "$output" "created $vault"
  is "$(find "$vault" -path "$vault/.git" -prune -o -type f -exec shasum {} + | sort; cat "$HOME/.claude/settings.json" "$ORCA_STUB/automations.json")" "$before"
}
