# shellcheck shell=bash
# Sourced by the scripts that count corrections.
correction_trailer='(^|[[:space:]])Correction: [a-z0-9-]+$'

# correction_commits <repo> [<revision>]: one "<key> <commit> <date>" line per correction a commit names, newest commit first, on every branch
# or only in the history of <revision>. One walk of the history for all records.
correction_commits() {
  git -C "$1" log "${2:---all}" -E --grep="$correction_trailer" --format='@@commit %h %cs%n%B' 2>/dev/null | awk -v trailer="$correction_trailer" '
    /^@@commit / { commit = $2 " " $3; next }
    $0 ~ trailer && !seen[$NF]++ { print $NF, commit }' || true
}
