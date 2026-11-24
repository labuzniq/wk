#!/usr/bin/env bash
# Runs before every file write of the agent: only a wiki-ingest or wiki-lint session may write a vault's wiki/ pages. Must stay fast: no network, no Orca.
kit="$(cd "$(dirname "$0")/.." && pwd)"
input=$(cat)
case "$input" in */wiki/*) ;; *) exit 0 ;; esac
pass() { echo "check-wiki-write: $1, so the wiki rule was not checked for this write" >&2; exit 1; }
command -v jq >/dev/null || pass "'jq' is not on PATH (install it with \`brew install jq\`)"
fields=$(jq -r '[.session_id, .cwd, (.tool_input | .file_path // .notebook_path)] | map(strings | select(length > 0)) | if length == 3 then join("\u001f") else error("fields") end' <<<"$input" 2>/dev/null) \
  || pass "the hook input is not the JSON a file write sends"
IFS=$'\037' read -r session_id cwd file <<<"$fields"
case "$file" in /*) ;; *) file="$cwd/$file" ;; esac
case "$file" in */wiki/*) ;; *) exit 0 ;; esac
case "$session_id" in ''|*/*) pass "the session id '$session_id' is not a file name" ;; esac
# The wiki skills mark their session in their first step; that mark is what lets them write.
marks="$HOME/.local/state/workspace-kit/sessions/no-capture"
[ ! -f "$marks/$session_id" ] || exit 0

# The file may not exist yet: take the nearest folder that does, with links resolved, as git prints its paths that way.
folder=$(dirname "$file")
rest=$(basename "$file")
until [ -d "$folder" ]; do
  rest="$(basename "$folder")/$rest"
  folder=$(dirname "$folder")
done
file="$(cd "$folder" && pwd -P)/$rest"

# wiki_of <folder>: the wiki folders of the project that holds <folder>, in this checkout and in the primary one.
wiki_of() (
  cd "$1" 2>/dev/null || exit 0
  # shellcheck source=../lib/project.sh
  . "$kit/lib/project.sh" || exit 0
  [ -f "$manifest" ] || exit 0
  vault=$(manifest_value vault)
  vault=${vault%/}
  [ -n "$vault" ] || exit 0
  case "$vault" in /*) echo "$vault/wiki" ;; *) printf '%s\n' "$root/$vault/wiki" "$primary/$vault/wiki" ;; esac
)

while read -r wiki; do
  [ -n "$wiki" ] || continue
  case "$file" in "$wiki"/*)
    inbox="$(dirname "$wiki")/raw/inbox"
    file=$(printf '%s' "$file" | LC_ALL=C tr -d '\000-\037\177')
    printf 'Blocked by the workspace kit: %s is a wiki page, and wiki pages are written only by the `wiki-ingest` and `wiki-lint` skills. To record something, write a dated note to %s/<date>-<title>.md; the next ingest brings it into the wiki. To change the wiki now, run the `wiki-ingest` or `wiki-lint` skill. Only if this session is running one of those two skills, its first step did not mark the session: run `mkdir -p %s && touch %s/%s`, then write again. That mark also keeps the session out of the wiki, so never set it for other work.\n' "$file" "$inbox" "$marks" "$marks" "$session_id" >&2
    exit 2 ;;
  esac
done <<EOF
$(wiki_of "$folder"; wiki_of "$cwd")
EOF
exit 0
