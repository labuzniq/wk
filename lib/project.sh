# Sourced by scripts that run inside a project. Sets root, primary, manifest; returns 1 outside a git repo.
root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
primary=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
manifest="$root/.workspace-kit.toml"
state_dir="$HOME/.local/state/workspace-kit"

manifest_value() { sed -n "s/^$1 = \"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" "$manifest" | head -1; }

vault_dir() {
  local vault
  vault=$(manifest_value vault)
  case "$vault" in /*) echo "$vault" ;; *) echo "$primary/$vault" ;; esac
}

path_key() { printf '%s' "$1" | shasum | cut -d' ' -f1; }
