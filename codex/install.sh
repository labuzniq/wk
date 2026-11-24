# shellcheck shell=bash disable=SC2154 # kit, backup, backup_dir and link come from install.sh, which sources this file
# Sets up Codex next to Claude Code, only when `codex` is on PATH: the shared instructions, the kit's skills and the hooks Codex has events for.
if ! command -v codex >/dev/null; then
  echo "skipped Codex: 'codex' is not on PATH; run install.sh again after installing it"
else
  codex_dir="${CODEX_HOME:-$HOME/.codex}"
  mkdir -p "$codex_dir"

  # Codex cannot import a file, so the shared instructions are copied between two marker lines. The rest of the file is the person's.
  agents_md="$codex_dir/AGENTS.md"
  begin='<!-- workspace-kit:begin. install.sh rewrites everything up to the end marker from the kit'"'"'s claude/CLAUDE.md. Write your own rules below the end marker. -->'
  end='<!-- workspace-kit:end -->'
  if [ -e "$agents_md" ]; then
    current=$(cat "$agents_md")
    rest=$(awk '/^<!-- workspace-kit:begin/ {skip = 1} !skip {print} /^<!-- workspace-kit:end -->/ {skip = 0}' "$agents_md" | sed '/./,$!d')
  else
    current=""
    rest='# My instructions'
  fi
  wanted=$(printf '%s\n%s\n%s\n\n%s' "$begin" "$(cat "$kit/claude/CLAUDE.md")" "$end" "$rest")
  if [ ! -e "$agents_md" ]; then
    printf '%s\n' "$wanted" > "$agents_md"
    echo "wrote $agents_md: it holds the kit's shared instructions; add your own rules below them"
  elif [ "$wanted" != "$current" ]; then
    mkdir -p "$backup_dir"
    cp -L "$agents_md" "$backup_dir/"
    echo "backed up $agents_md to $backup_dir"
    # Written in place, so a file that is a link into the person's own dotfiles stays a link.
    printf '%s\n' "$wanted" > "$agents_md"
    if grep -q '^<!-- workspace-kit:begin' <<<"$current"; then
      echo "updated the kit's instructions in $agents_md; your text is kept"
    else
      echo "added the kit's instructions at the top of $agents_md; your text is kept"
    fi
  fi
  [ ! -s "$codex_dir/AGENTS.override.md" ] \
    || echo "note: $codex_dir/AGENTS.override.md is not empty, so Codex reads it instead of $agents_md and the kit's instructions are not loaded"

  # Codex finds user skills in ~/.agents/skills, where the third-party skills already are; the kit's own skills are linked in.
  mkdir -p "$HOME/.agents/skills"
  for source in "$kit/skills"/*/; do
    source="${source%/}"
    target="$HOME/.agents/skills/$(basename "$source")"
    if [ -d "$target" ] && [ ! -L "$target" ]; then
      echo "kept real folder $target (not linked to $source)"
    else
      link "$source" "$target"
    fi
  done

  hooks_file="$codex_dir/hooks.json"
  current='{}'
  [ ! -f "$hooks_file" ] || current=$(jq . "$hooks_file")
  merged=$(jq --arg kit "$kit" --slurpfile fragment "$kit/codex/hooks.fragment.json" '
    def add_missing($new): reduce $new[] as $x (.; if index([$x]) then . else . + [$x] end);
    reduce ($fragment[0] | walk(if type == "string" then sub("__KIT__"; $kit) else . end) | .hooks | to_entries[]) as $event (.;
      .hooks[$event.key] = ((.hooks[$event.key] // []) | add_missing($event.value)))' <<<"$current")
  if [ "$merged" != "$current" ]; then
    backup "$hooks_file"
    printf '%s\n' "$merged" > "$hooks_file.new"
    mv "$hooks_file.new" "$hooks_file"
    echo "merged hooks into $hooks_file"
    echo "Codex runs a new or changed hook only after you trust it: open /hooks in Codex and trust the workspace-kit hooks"
    echo "Codex has no WorktreeCreate or WorktreeRemove hook: a worktree Codex makes itself does not become an Orca card (see docs/verified.md)"
  fi
fi
