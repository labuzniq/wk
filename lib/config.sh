WK_CONFIG="$HOME/.config/workspace-kit/config.toml"

wk_config() {
  local value
  value=$(sed -n "s/^$1 = \"\(.*\)\"$/\1/p" "$WK_CONFIG")
  [ -n "$value" ] || { echo "workspace-kit: '$1' is not set in $WK_CONFIG" >&2; return 1; }
  printf '%s\n' "$value"
}
