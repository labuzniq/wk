# shellcheck shell=bash disable=SC2034 # the variables are for the test files that load this
# Shared setup for the kit's tests: a throwaway HOME that looks like an installed kit, with stand-ins for orca and gh on PATH.
kit="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup_home() {
  # uv keeps its cache and its Python under HOME; point it at the real ones so a test never downloads.
  UV_CACHE_DIR="$(uv cache dir)"
  UV_PYTHON_INSTALL_DIR="$(uv python dir)"
  export UV_CACHE_DIR UV_PYTHON_INSTALL_DIR
  unset ORCA_WORKTREE_ID

  HOME="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/home"
  export HOME
  export ORCA_STUB="$HOME/orca-stub" GH_STUB="$HOME/gh-stub"
  export PATH="$kit/test/stubs:$PATH"
  state="$HOME/.local/state/workspace-kit"

  mkdir -p "$HOME/.config/workspace-kit" "$HOME/projects" "$ORCA_STUB" "$GH_STUB"
  echo '[]' > "$ORCA_STUB/repos.json"
  echo '[]' > "$ORCA_STUB/automations.json"
  touch "$ORCA_STUB/calls" "$GH_STUB/calls"
  printf '[user]\n  name = Test\n  email = test@example.com\n[init]\n  defaultBranch = main\n' > "$HOME/.gitconfig"
  printf 'projects_root = "%s"\nkit = "%s"\n' "$HOME/projects" "$HOME/kit" > "$HOME/.config/workspace-kit/config.toml"

  # The installed kit: the real templates, and a lock file that matches one stand-in agent.
  mkdir -p "$HOME/kit/agents" "$HOME/.claude/agents/ecc" "$HOME/.claude/skills"
  ln -s "$kit/templates" "$HOME/kit/templates"
  echo "stand-in agent" > "$HOME/.claude/agents/ecc/reviewer.md"
  jq -n --arg sha "$(shasum -a 256 "$HOME/.claude/agents/ecc/reviewer.md" | cut -d' ' -f1)" \
    '{agents: {reviewer: {installed_sha256: $sha}}}' > "$HOME/kit/agents/agents.lock"

  # The one third-party skill `wk adopt` reads its tracker docs from.
  matt="$HOME/.agents/skills/setup-matt-pocock-skills"
  mkdir -p "$matt"
  for doc in SKILL issue-tracker-local issue-tracker-github triage-labels domain; do
    echo "# stand-in $doc" > "$matt/$doc.md"
  done
  ln -s "$matt" "$HOME/.claude/skills/setup-matt-pocock-skills"
}

# new_repo <path>: a git repo with one commit on main.
new_repo() {
  git init -q "$1"
  git -C "$1" commit -q --allow-empty -m "chore: start"
}

# adopted_project: a project under the projects folder with the capsule committed; sets $project and cds into it.
adopted_project() {
  project="$HOME/projects/demo"
  mkdir -p "$project"
  cd "$project" || return 1
  "$kit/libexec/wk-adopt" > /dev/null
  git add -A
  git commit -q -m "chore: add workspace-kit capsule"
}
