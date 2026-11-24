#!/usr/bin/env bats
# Codex next to Claude Code: the installer part for Codex, and a Codex session through the queue and `wk transcript`.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

# Same copy of the kit as in install.bats, plus a stand-in `codex` that is only found on PATH.
setup() {
  setup_home
  rm -r "$HOME/.claude" "$HOME/.config/workspace-kit"
  copy="$HOME/kit copy"
  mkdir -p "$copy/bin" "$copy/docs" "$HOME/codex-bin"
  cp -R "$kit/install.sh" "$kit/claude" "$kit/codex" "$kit/skills" "$kit/skills.txt" "$kit/templates" "$copy/"
  cp "$kit/docs/orca-settings.md" "$copy/docs/"
  printf '#!/usr/bin/env bash\necho "$*" >> "$HOME/wk-calls"\n' > "$copy/bin/wk"
  printf '#!/usr/bin/env bash\necho "codex stand-in: $*" >&2\nexit 64\n' > "$HOME/codex-bin/codex"
  chmod +x "$copy/bin/wk" "$HOME/codex-bin/codex"
  agents_md="$HOME/.codex/AGENTS.md"
  hooks="$HOME/.codex/hooks.json"
  demo="$HOME/projects/demo"
}

install() { run "$copy/install.sh" "$HOME/projects"; }
with_codex() { PATH="$HOME/codex-bin:$PATH" "$@"; }

snapshot() {
  find "$HOME/.claude" "$HOME/.codex" "$HOME/.agents" "$HOME/.config" "$HOME/.local/bin" -type f -exec shasum {} + 2>/dev/null | sort
  find "$HOME/.claude" "$HOME/.codex" "$HOME/.agents" "$HOME/.local/bin" -type l -exec ls -l {} + 2>/dev/null | awk '{print $(NF-2), $NF}' | sort
}

# The kit's part of ~/.codex/AGENTS.md: the lines between the first begin marker and the end marker.
kit_block() { awk '/^<!-- workspace-kit:end/ {exit} on {print} /^<!-- workspace-kit:begin/ {on = 1}' "$1"; }

@test "without codex on PATH the installer leaves Codex alone and says so in one line" {
  install
  [ "$status" -eq 0 ]
  is "$(grep -c Codex <<<"$output")" 1
  [[ "$output" == *"skipped Codex: 'codex' is not on PATH"* ]]
  [ ! -e "$HOME/.codex" ]
  [ ! -e "$HOME/.agents/skills/wiki-ingest" ]
}

@test "with codex on PATH, Codex gets the shared instructions, the kit's skills and the hooks it has events for" {
  with_codex install
  [ "$status" -eq 0 ]
  is "$(kit_block "$agents_md")" "$(cat "$copy/claude/CLAUDE.md")"
  grep -q '^# My instructions' "$agents_md"
  [[ "$output" == *"wrote $agents_md"* ]]
  for skill in project-setup wiki-ingest wiki-lint; do
    is "$(readlink "$HOME/.agents/skills/$skill")" "$copy/skills/$skill"
  done
  is "$(jq -r '.hooks | keys | join(" ")' "$hooks")" "PreCompact SessionEnd SessionStart Stop"
  is "$(jq -r '.hooks.SessionStart[0] | .matcher + " " + .hooks[0].command' "$hooks")" "startup|resume $copy/hooks/session-start.sh"
  is "$(jq -r '.hooks.SessionEnd[0].hooks[0].command' "$hooks")" "$copy/hooks/enqueue-session.sh"
  is "$(jq -r '.hooks.PreCompact[0].hooks[0].command' "$hooks")" "$copy/hooks/enqueue-session.sh"
  is "$(jq -r '.hooks.Stop[0].hooks[0].command' "$hooks")" "$copy/hooks/stop.sh"
  [[ "$output" == *"merged hooks into $hooks"* ]]
  [[ "$output" == *"open /hooks in Codex"* ]]
  [[ "$output" == *"Codex has no WorktreeCreate or WorktreeRemove hook"* ]]
}

@test "a second run with codex changes nothing and prints no change" {
  with_codex install
  echo "- my own Codex rule" >> "$agents_md"
  before=$(snapshot)
  with_codex install
  [ "$status" -eq 0 ]
  is "$(snapshot)" "$before"
  is "$(grep -E '^(wrote|moved|added|updated|merged|linked|backed up) ' <<<"$output" || true)" ""
}

@test "instructions the person wrote for Codex are kept below the kit's part, with a backup" {
  mkdir -p "$HOME/.codex"
  printf '# Mine\n- my own rule\n' > "$agents_md"
  with_codex install
  [ "$status" -eq 0 ]
  is "$(kit_block "$agents_md")" "$(cat "$copy/claude/CLAUDE.md")"
  is "$(sed -n '/^<!-- workspace-kit:end/,$p' "$agents_md" | sed 1d)" $'\n# Mine\n- my own rule'
  is "$(cat "$HOME"/.claude/backup/*/AGENTS.md)" $'# Mine\n- my own rule'
  [[ "$output" == *"added the kit's instructions at the top of $agents_md; your text is kept"* ]]
}

@test "after a git pull changes the shared instructions, the next run updates the kit's part and keeps the rest" {
  with_codex install
  echo "- my own Codex rule" >> "$agents_md"
  echo "- a new shared rule" >> "$copy/claude/CLAUDE.md"
  with_codex install
  [ "$status" -eq 0 ]
  is "$(kit_block "$agents_md")" "$(cat "$copy/claude/CLAUDE.md")"
  is "$(tail -1 "$agents_md")" "- my own Codex rule"
  [[ "$output" == *"updated the kit's instructions in $agents_md"* ]]
}

@test "hooks the person set in Codex are kept, and CODEX_HOME moves the Codex files" {
  export CODEX_HOME="$HOME/codex-home"
  mkdir -p "$CODEX_HOME"
  echo '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "/mine.sh"}]}]}}' > "$CODEX_HOME/hooks.json"
  with_codex install
  [ "$status" -eq 0 ]
  is "$(jq -r '[.hooks.Stop[].hooks[0].command] | join(" ")' "$CODEX_HOME/hooks.json")" "/mine.sh $copy/hooks/stop.sh"
  [ -f "$CODEX_HOME/AGENTS.md" ]
  [ ! -e "$HOME/.codex" ]
}

@test "an AGENTS.override.md that hides the kit's instructions is named" {
  mkdir -p "$HOME/.codex"
  echo "- override" > "$HOME/.codex/AGENTS.override.md"
  with_codex install
  [[ "$output" == *"$HOME/.codex/AGENTS.override.md is not empty, so Codex reads it instead of $agents_md"* ]]
}

@test "a skill folder the person put in ~/.agents/skills under a kit skill's name is kept" {
  mkdir -p "$HOME/.agents/skills/wiki-lint"
  with_codex install
  [ ! -L "$HOME/.agents/skills/wiki-lint" ]
  [[ "$output" == *"kept real folder $HOME/.agents/skills/wiki-lint"* ]]
}

# A Codex rollout file in the format the Codex source writes (codex-rs/history, codex-rs/protocol/src/models.rs).
codex_rollout() {
  cat <<'JSONL'
{"timestamp":"2026-11-24T10:00:00.000Z","type":"session_meta","payload":{"id":"019a-codex","session_id":"019a-codex","timestamp":"2026-11-24T10:00:00.000Z","cwd":"/work","originator":"codex_cli_rs","cli_version":"0.99.0"}}
{"timestamp":"2026-11-24T10:00:00.001Z","type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"<permissions instructions>sandbox</permissions instructions>"}]}}
{"timestamp":"2026-11-24T10:00:00.002Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"# AGENTS.md instructions for /work\n\n<INSTRUCTIONS>\nUse simple English.\n</INSTRUCTIONS>"},{"type":"input_text","text":"<environment_context>\n  <cwd>/work</cwd>\n</environment_context>"}]}}
{"timestamp":"2026-11-24T10:00:01.000Z","type":"turn_context","payload":{"cwd":"/work","model":"gpt-5"}}
{"timestamp":"2026-11-24T10:00:01.001Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Add a login page"}]}}
{"timestamp":"2026-11-24T10:00:01.002Z","type":"event_msg","payload":{"type":"user_message","message":"Add a login page"}}
{"timestamp":"2026-11-24T10:00:02.000Z","type":"response_item","payload":{"type":"reasoning","summary":[]}}
{"timestamp":"2026-11-24T10:00:02.001Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"ls\"]}","call_id":"c1"}}
{"timestamp":"2026-11-24T10:00:03.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Done: login.html"}]}}
{"timestamp":"2026-11-24T10:00:03.001Z","type":"event_msg","payload":{"type":"agent_message","message":"Done: login.html"}}
{"timestamp":"2026-11-24T10:00:04.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<ide_context>open file: a.ts</ide_context>\n## My request for Codex:\nUse a form"}]}}
JSONL
}

@test "wk transcript reads a Codex rollout: user and assistant text, without injected context, tool calls or event copies" {
  codex_rollout > "$HOME/rollout.jsonl"
  run "$kit/bin/wk" transcript "$HOME/rollout.jsonl"
  [ "$status" -eq 0 ]
  is "$output" $'user_turns: 2\n\n## user\nAdd a login page\n\n## assistant\nDone: login.html\n\n## user\nUse a form'
}

@test "wk transcript still reads a Claude Code transcript" {
  printf '%s\n' \
    '{"type":"user","message":{"role":"user","content":"Fix the bug"}}' \
    '{"type":"assistant","message":{"content":[{"type":"text","text":"Fixed"},{"type":"tool_use","name":"Bash"}]}}' \
    '{"type":"user","isSidechain":true,"message":{"content":"subagent"}}' > "$HOME/claude.jsonl"
  run "$kit/bin/wk" transcript "$HOME/claude.jsonl"
  is "$output" $'user_turns: 1\n\n## user\nFix the bug\n\n## assistant\nFixed'
}

@test "a finished Codex session is queued like a Claude Code session, and its transcript reads" {
  new_repo "$demo"
  printf 'slug = "demo"\ntype = "code"\nvault = "knowledge-base"\n' > "$demo/.workspace-kit.toml"
  codex_rollout > "$HOME/rollout.jsonl"
  # The fields of Codex's SessionEnd input, from codex-rs/hooks/schema/generated/session-end.command.input.schema.json.
  jq -n --arg cwd "$demo" --arg path "$HOME/rollout.jsonl" \
    '{session_id: "019a-codex", transcript_path: $path, cwd: $cwd, hook_event_name: "SessionEnd", reason: "other"}' \
    | "$kit/hooks/enqueue-session.sh"
  entry=$(cat "$state"/sessions/demo/queue/*-019a-codex.json)
  is "$(jq -r '[.session_id, .project_slug, .event] | join(" ")' <<<"$entry")" "019a-codex demo SessionEnd"
  run "$kit/bin/wk" transcript "$(jq -r .transcript_path <<<"$entry")"
  is "$(head -1 <<<"$output")" "user_turns: 2"
}

@test "a session without a transcript (a Codex ephemeral session) queues nothing" {
  new_repo "$demo"
  printf 'slug = "demo"\ntype = "code"\nvault = "knowledge-base"\n' > "$demo/.workspace-kit.toml"
  jq -n --arg cwd "$demo" '{session_id: "e1", transcript_path: null, cwd: $cwd, hook_event_name: "SessionEnd", reason: "other"}' \
    | "$kit/hooks/enqueue-session.sh"
  [ ! -d "$state/sessions/demo/queue" ] || is "$(ls "$state/sessions/demo/queue")" ""
}

# The fields of Codex's SessionStart input, from codex-rs/hooks/schema/generated/session-start.command.input.schema.json.
codex_session_starts() {
  jq -n --arg cwd "$1" '{session_id: "s1", transcript_path: null, cwd: $cwd, hook_event_name: "SessionStart",
    model: "gpt-5", permission_mode: "default", source: "startup"}' | "$kit/hooks/session-start.sh"
}

@test "the session-start hook answers Codex's SessionStart input with plain text, which Codex adds as context" {
  mkdir -p "$HOME/.config/workspace-kit" "$HOME/.claude/skills"
  printf 'projects_root = "%s"\nkit = "%s"\n' "$HOME/projects" "$HOME/kit" > "$HOME/.config/workspace-kit/config.toml"
  adopted_project
  run codex_session_starts "$project"
  [ "$status" -eq 0 ]
  [[ "$output" == "Project: demo (code)"* ]]
  [[ "$output" != "{"* ]]
}

@test "a begin marker without an end marker keeps everything below it" {
  mkdir -p "$HOME/.codex"
  printf '<!-- workspace-kit:begin\n- my own rule\n' > "$agents_md"
  with_codex install
  [ "$status" -eq 0 ]
  is "$(kit_block "$agents_md")" "$(cat "$copy/claude/CLAUDE.md")"
  grep -qx -- '- my own rule' "$agents_md"
  before=$(snapshot)
  with_codex install
  is "$(snapshot)" "$before"
  grep -qx -- '- my own rule' "$agents_md"
}
