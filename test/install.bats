#!/usr/bin/env bats
# `install.sh` in a throwaway HOME: the config, the global instructions and the settings. Skill and agent syncs are stand-ins.

# shellcheck disable=SC2154 # kit and the helpers come from helpers.bash
load helpers

# The installer finds the kit by its own place, so the test runs a copy whose `wk` only logs its calls.
setup() {
  setup_home
  rm -r "$HOME/.claude" "$HOME/.config/workspace-kit"
  copy="$HOME/kit copy"
  mkdir -p "$copy/bin" "$copy/docs"
  cp -R "$kit/install.sh" "$kit/claude" "$kit/skills" "$kit/skills.txt" "$kit/templates" "$copy/"
  cp "$kit/docs/orca-settings.md" "$copy/docs/"
  printf '#!/usr/bin/env bash\necho "$*" >> "$HOME/wk-calls"\n' > "$copy/bin/wk"
  chmod +x "$copy/bin/wk"
  mine="$HOME/.claude/CLAUDE.md"
  import="@$HOME/kit\\ copy/claude/CLAUDE.md"
}

install() { run "$copy/install.sh" "$HOME/projects"; }

# Everything the installer may write, with its content; links show where they point.
snapshot() {
  find "$HOME/.claude" "$HOME/.config" "$HOME/.local/bin" -type f -exec shasum {} + | sort
  find "$HOME/.claude" "$HOME/.local/bin" -type l -exec ls -l {} + | awk '{print $(NF-2), $NF}' | sort
}

changes() { grep -E '^(wrote|moved|added|merged|linked|backed up) ' <<<"$output" || true; }

@test "a fresh install writes the person's own instructions file, which imports the shared one" {
  install
  [ "$status" -eq 0 ]
  [ ! -L "$mine" ]
  is "$(head -1 "$mine")" "$import"
  is "$(grep -l '## Language' "$mine" "$copy/claude/CLAUDE.md")" ""
  [[ "$output" == *"wrote $mine"* ]]
  is "$(jq -r '.hooks.Stop[0].hooks[0].command' "$HOME/.claude/settings.json")" "$copy/hooks/stop.sh"
  grep -qx "kit = \"$copy\"" "$HOME/.config/workspace-kit/config.toml"
  is "$(cat "$HOME/wk-calls")" $'skills-sync\nagents-sync'
  [ ! -e "$HOME/.claude/backup" ]
}

@test "a second run changes nothing and says so by printing no change" {
  install
  echo "- my own rule" >> "$mine"
  before=$(snapshot)
  install
  [ "$status" -eq 0 ]
  is "$(snapshot)" "$before"
  is "$(changes)" ""
}

@test "an install of the old layout moves to the new one, keeps the personal lines and makes a backup" {
  mkdir -p "$HOME/.claude"
  ln -s "$copy/claude/CLAUDE.md" "$mine"
  install
  [ "$status" -eq 0 ]
  [ ! -L "$mine" ]
  is "$(head -1 "$mine")" "$import"
  grep -q '^- Use simple English' "$mine"
  [[ "$output" == *"moved $mine to the new layout"* ]]
  is "$(readlink "$HOME"/.claude/backup/*/CLAUDE.md)" "$copy/claude/CLAUDE.md"
  before=$(snapshot)
  install
  is "$(snapshot)" "$before"
}

@test "instructions the person wrote themselves are kept, with the import added and a backup" {
  mkdir -p "$HOME/.claude"
  printf '# Mine\n- my own rule\n' > "$mine"
  install
  [ "$status" -eq 0 ]
  is "$(cat "$mine")" "$import"$'\n\n# Mine\n- my own rule'
  is "$(cat "$HOME"/.claude/backup/*/CLAUDE.md)" $'# Mine\n- my own rule'
  [[ "$output" == *"your text is kept"* ]]
}

@test "instructions that are a link into the person's own files stay a link, and the backup holds the old text" {
  mkdir -p "$HOME/.claude" "$HOME/dotfiles"
  echo "- my own rule" > "$HOME/dotfiles/claude.md"
  ln -s ../dotfiles/claude.md "$mine"
  install
  [ "$status" -eq 0 ]
  is "$(readlink "$mine")" ../dotfiles/claude.md
  is "$(cat "$HOME/dotfiles/claude.md")" "$import"$'\n\n- my own rule'
  [ ! -L "$(echo "$HOME"/.claude/backup/*/CLAUDE.md)" ]
  is "$(cat "$HOME"/.claude/backup/*/CLAUDE.md)" "- my own rule"
}

@test "the doctor reports an install of the old layout, and the installer fixes it" {
  install
  adopted_project
  ln -sf "$copy/claude/CLAUDE.md" "$mine"
  run "$kit/bin/wk" doctor
  [[ "$output" == *"instructions: $mine does not import"* ]]
  install
  run "$kit/bin/wk" doctor
  [[ "$output" != *instructions:* ]]
}
