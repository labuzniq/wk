#!/usr/bin/env bash
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

link "$kit/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"

kit_skills=$(cat "$kit/skills.txt" | cut -d' ' -f2- | tr ' ' '\n' | jq -R . | jq -sc '. + ["orca-cli", "orca-computer-use", "orchestration", "resolving-merge-conflicts"]')
merged=$(jq --arg kit "$kit" --argjson skills "$kit_skills" --slurpfile fragment "$kit/claude/settings.fragment.json" -f "$kit/claude/merge-settings.jq" "$claude_dir/settings.json")
if [ "$merged" != "$(jq . "$claude_dir/settings.json")" ]; then
  backup "$claude_dir/settings.json"
  printf '%s\n' "$merged" > "$claude_dir/settings.json.new"
  mv "$claude_dir/settings.json.new" "$claude_dir/settings.json"
  echo "merged settings fragment into $claude_dir/settings.json"
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

cat "$kit/docs/orca-settings.md"
