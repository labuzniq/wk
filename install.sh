#!/usr/bin/env bash
# Installs the kit for one person. Can run again at any time: it prints what it wrote, moved or backed up, and keeps the rest.
set -euo pipefail

kit="$(cd "$(dirname "$0")" && pwd)"
config="$HOME/.config/workspace-kit/config.toml"
claude_dir="$HOME/.claude"
backup_dir="$claude_dir/backup/$(date +%Y%m%d-%H%M%S)"

for tool in jq npx orca uv; do
  command -v "$tool" >/dev/null || { echo "install: '$tool' is required but not on PATH" >&2; exit 1; }
done

backup() {
  [ -e "$1" ] || return 0
  mkdir -p "$backup_dir"
  cp -P "$1" "$backup_dir/"
  echo "backed up $1 to $backup_dir"
}

link() {
  local source="$1" target="$2"
  [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ] && return 0
  [ -e "$target" ] && [ ! -L "$target" ] && [ ! -d "$target" ] && backup "$target"
  ln -sfn "$source" "$target"
  echo "linked $target -> $source"
}

if [ ! -f "$config" ]; then
  projects_root="${1:?first run: install.sh <projects_root>}"
  mkdir -p "$(dirname "$config")"
  printf 'projects_root = "%s"\nkit = "%s"\n' "$projects_root" "$kit" > "$config"
  echo "wrote $config"
fi

# ~/.claude/CLAUDE.md is the person's own file. It imports the shared instructions; the rest of it is never replaced.
shared="$kit/claude/CLAUDE.md"
personal="$claude_dir/CLAUDE.md"
import="@${shared// /\\ }"
note='<!-- This file is yours: install.sh never replaces it. Keep the @ line above, it loads the instructions the kit shares. Write your own rules below. -->'
mkdir -p "$claude_dir"
if [ -L "$personal" ] && [ "$(readlink -f "$personal")" = "$(readlink -f "$shared")" ]; then
  backup "$personal"
  rm "$personal"
  { printf '%s\n\n# My instructions\n\n%s\n\n' "$import" "$note"; cat "$kit/claude/personal-before-split.md"; } > "$personal"
  echo "moved $personal to the new layout: it was a link to $shared, now it is your own file that imports it and holds the personal lines the kit used to ship"
elif [ ! -e "$personal" ]; then
  printf '%s\n\n# My instructions\n\n%s\n' "$import" "$note" > "$personal"
  echo "wrote $personal: it imports $shared; add your own rules to it"
elif ! grep -qxF "$import" "$personal"; then
  # A copy of the text, not of a link: the file behind a link is about to change.
  mkdir -p "$backup_dir"
  cp -L "$personal" "$backup_dir/"
  echo "backed up $personal to $backup_dir"
  text=$(cat "$personal")
  # Written in place, so a file that is a link into the person's own dotfiles stays a link.
  printf '%s\n\n%s\n' "$import" "$text" > "$personal"
  echo "added the import of $shared as the first line of $personal; your text is kept"
fi

kit_skills=$(cat "$kit/skills.txt" | cut -d' ' -f2- | tr ' ' '\n' | jq -R . | jq -sc '. + ["orca-cli", "orca-computer-use", "orchestration", "resolving-merge-conflicts"]')
current='{}'
[ ! -f "$claude_dir/settings.json" ] || current=$(jq . "$claude_dir/settings.json")
merged=$(jq --arg kit "$kit" --argjson skills "$kit_skills" --slurpfile fragment "$kit/claude/settings.fragment.json" -f "$kit/claude/merge-settings.jq" <<<"$current")
if [ "$merged" != "$current" ]; then
  backup "$claude_dir/settings.json"
  printf '%s\n' "$merged" > "$claude_dir/settings.json.new"
  mv "$claude_dir/settings.json.new" "$claude_dir/settings.json"
  echo "merged settings fragment into $claude_dir/settings.json"
  # The file as it was before this run is in the backup, or there was none: `wk shared-vault` needs no second copy.
  export WK_SETTINGS_SAVED=1
fi

mkdir -p "$claude_dir/skills"
installed() { [ -e "$HOME/.agents/skills/$1/SKILL.md" ]; }

"$kit/bin/wk" skills-sync

missing=()
for skill in orca-cli orca-computer-use orchestration; do installed "$skill" || missing+=(--skill "$skill"); done
[ ${#missing[@]} -eq 0 ] || orca skills install "${missing[@]}"

for source in "$HOME/.agents/skills"/*/ "$kit/skills"/*/; do
  source="${source%/}"
  target="$claude_dir/skills/$(basename "$source")"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    echo "kept real folder $target (not linked to $source)"
  else
    link "$source" "$target"
  fi
done

"$kit/bin/wk" agents-sync

mkdir -p "$HOME/.local/bin"
link "$kit/bin/wk" "$HOME/.local/bin/wk"

# Last, so that a closed Orca leaves everything above installed.
shared_vault=0
"$kit/bin/wk" shared-vault || shared_vault=$?

cat "$kit/docs/orca-settings.md"
exit "$shared_vault"
