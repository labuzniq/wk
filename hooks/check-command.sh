#!/usr/bin/env bash
# Runs before every Bash call of the agent: blocks the git calls the kit's rules forbid and says what to do instead. Must stay fast: no network, no Orca.
input=$(cat)
case "$input" in *git*) ;; *) exit 0 ;; esac
pass() { echo "check-command: $1, so no rule was checked for this command" >&2; exit 1; }
command -v jq >/dev/null || pass "'jq' is not on PATH (install it with \`brew install jq\`)"
# Reading the command takes longer than a command should wait once it has thousands of words.
[ ${#input} -le 12000 ] || pass "the command is longer than 12,000 characters"
calls=$(jq -r -f "$(dirname "$0")/check-command.jq" <<<"$input" 2>/dev/null) || pass "the hook input is not the JSON a Bash call sends"

block() { printf 'Blocked by the workspace kit: %s\n' "$1" >&2; exit 2; }

conventional='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^()]+\))?!?: [^ ]'
written_by_git='^(Merge|Revert|fixup!|squash!|amend!) '

while IFS=$'\t' read -r kind folder value; do
  case "$kind" in
    worktree-add)
      case "$folder/" in '?/'|/tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) continue ;; esac
      block '`git worktree add` makes a worktree that Orca does not know. Create it through Orca instead: `orca worktree create --name <name> --issue <number>` (load the `orca-cli` skill for the other flags). A test that needs a plain git worktree makes it in a throwaway repo under /tmp or the folder `mktemp -d` gives.'
      ;;
    push)
      [ "$value" != HEAD ] || value=$(git -C "$folder" branch --show-current 2>/dev/null)
      case "$value" in
        main|master|'*') block "this force-push would overwrite \`${value/\*/every branch, main included}\`. Never force-push main. To undo something on main, add a commit (\`git revert <commit>\`) and push it without force. To force-push your own branch, name it: \`git push --force-with-lease origin <branch>\`. If the owner wants main overwritten, they run the command themselves." ;;
      esac
      ;;
    message|message-file)
      if [ "$kind" = message-file ]; then
        [ -f "$value" ] || continue
        value=$(head -c 4096 -- "$value" | grep -m1 '[^[:space:]]') || continue
      fi
      value=$(printf '%s' "$value" | LC_ALL=C tr -d '\000-\037\177')
      value=${value:0:200}
      grep -Eq "$conventional|$written_by_git" <<<"$value" \
        || block "the commit message starts with \"$value\", which is not a conventional commit. Start the first line with a type, a colon and a space, for example \`fix: keep the queue file when ingest fails\`. Types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test. A scope and \`!\` may follow the type: \`feat(board)!: ...\`."
      ;;
  esac
done <<<"$calls"
exit 0
