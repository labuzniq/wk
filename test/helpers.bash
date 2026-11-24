# shellcheck shell=bash disable=SC2034 # the variables are for the test files that load this
# Shared setup for the kit's tests: a throwaway HOME that looks like an installed kit, with stand-ins for orca and gh on PATH.
kit="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
# shellcheck source=../lib/checksum.sh
. "$kit/lib/checksum.sh"

setup_home() {
  # uv keeps its cache and its Python under HOME; point it at the real ones so a test never downloads.
  UV_CACHE_DIR="$(uv cache dir)"
  UV_PYTHON_INSTALL_DIR="$(uv python dir)"
  export UV_CACHE_DIR UV_PYTHON_INSTALL_DIR
  unset ORCA_WORKTREE_ID GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE XDG_CONFIG_HOME GH_TOKEN GITHUB_TOKEN
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

  HOME="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/home"
  export HOME GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  export ORCA_STUB="$HOME/orca-stub" GH_STUB="$HOME/gh-stub" NPX_STUB="$HOME/npx-stub"
  export PATH="$kit/test/stubs:$PATH"
  state="$HOME/.local/state/workspace-kit"

  mkdir -p "$HOME/.config/workspace-kit" "$HOME/projects" "$ORCA_STUB" "$GH_STUB" "$NPX_STUB"
  echo '[]' > "$ORCA_STUB/repos.json"
  echo '[]' > "$ORCA_STUB/automations.json"
  touch "$ORCA_STUB/calls" "$GH_STUB/calls" "$NPX_STUB/calls"
  printf '[user]\n  name = Test\n  email = test@example.com\n[init]\n  defaultBranch = main\n' > "$HOME/.gitconfig"
  printf 'projects_root = "%s"\nkit = "%s"\n' "$HOME/projects" "$HOME/kit" > "$HOME/.config/workspace-kit/config.toml"
  # A stand-in shared vault, so the doctor has no gap; `no_shared_vault` takes it away again.
  printf 'shared_vault = "%s"\n' "$HOME/shared-vault" >> "$HOME/.config/workspace-kit/config.toml"
  mkdir -p "$HOME/shared-vault" "$state"
  touch "$HOME/shared-vault/CLAUDE.md"
  echo "$HOME/shared-vault" > "$state/shared-vault-ready"

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
  jq -n --arg sha "$(skills_sha256 setup-matt-pocock-skills)" \
    '{installed_sha256: $sha, skills: {"setup-matt-pocock-skills": {}}}' > "$HOME/kit/skills.lock"
}

# no_shared_vault: the home of a kit installed before the shared vault existed.
no_shared_vault() {
  rm -rf "$HOME/shared-vault" "$state/shared-vault-ready"
  sed -i '' '/^shared_vault = /d' "$HOME/.config/workspace-kit/config.toml"
}

# new_repo <path>: a git repo with one commit on main.
new_repo() {
  git init -q "$1"
  git -C "$1" commit -q --allow-empty -m "chore: start"
}

# existing_repo: a repo with history and a GitHub remote, without a capsule; sets $project and cds into it.
# Pushes to that remote land in the bare repo $HOME/origin.git.
existing_repo() {
  project="$HOME/projects/legacy"
  git init -q --bare "$HOME/origin.git"
  git config --global "url.$HOME/origin.git.insteadOf" "git@github.com:someone/legacy.git"
  new_repo "$project"
  cd "$project" || return 1
  echo "old code" > main.txt
  git add main.txt
  git commit -q -m "feat: old code"
  git remote add origin git@github.com:someone/legacy.git
  git push -q -u origin main
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

# is <actual> <expected>: on a mismatch, prints both, so a failing test shows what it got.
is() { [ "$1" = "$2" ] || { printf 'expected: %s\n     got: %s\n' "$2" "$1"; return 1; }; }

# has <text> <part> / lacks <text> <part>: unlike a bare [[ ]] in the middle of a test, these fail the test on bash 3.2.
has() { [[ "$1" == *"$2"* ]] || { printf 'expected to find: %s\n       in: %s\n' "$2" "$1"; return 1; }; }
lacks() { [[ "$1" != *"$2"* ]] || { printf 'expected not to find: %s\n           in: %s\n' "$2" "$1"; return 1; }; }

# card_file <path>: where `wk board-sync` saves the card of the checkout at <path>.
card_file() { echo "$state/cards/$(printf '%s' "$1" | shasum | cut -d' ' -f1).json"; }
