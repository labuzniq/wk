#!/usr/bin/env bats
# The Bash rules hook: a git call that breaks a rule is blocked with what to do instead; everything else passes.

# shellcheck disable=SC2154 # kit and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  repo="$HOME/projects/demo"
  new_repo "$repo"
  # The test home is under the temp folder, where a plain git worktree is allowed; the worktree tests need a folder that is not.
  work=/Users/dev/projects/demo
}

# agent_runs <command> [cwd]: feed the hook what Claude Code sends before a Bash call.
agent_runs() {
  jq -n --arg command "$1" --arg cwd "${2:-$repo}" \
    '{session_id: "abc", transcript_path: "/transcripts/abc.jsonl", cwd: $cwd, permission_mode: "default", hook_event_name: "PreToolUse",
      tool_name: "Bash", tool_input: {command: $command, description: "a command"}, tool_use_id: "toolu_1"}' \
    | "$kit/hooks/check-command.sh"
}

# blocked <command> [cwd]: the hook must stop the call (exit 2) and say why on stderr, which Claude Code shows the agent.
blocked() {
  run agent_runs "$@"
  is "$status" 2
  [[ "$output" == "Blocked by the workspace kit: "* ]] || { echo "said: $output"; return 1; }
}

# allowed <command> [cwd]: the hook must let the call pass without a word.
allowed() {
  run agent_runs "$@"
  is "$status:$output" "0:"
}

@test "git worktree add is blocked and the message names the Orca command" {
  blocked "git worktree add ../demo-fix -b fix" "$work"
  [[ "$output" == *'orca worktree create --name <name> --issue <number>'* ]]
}

@test "git worktree add is blocked behind cd, git options, an env value and a chain" {
  blocked "cd $work && git worktree add ../x" /tmp
  blocked "git -C $work --no-pager worktree add ../x" /tmp
  blocked "GIT_TRACE=1 git worktree add ../x" "$work"
  blocked "git fetch; git worktree add --detach ../x" "$work"
  blocked "/usr/bin/git worktree add ../x" "$work"
  blocked "git worktree \\
  add ../x" "$work"
}

@test "git worktree add passes in a throwaway repo under the temp folder" {
  allowed "git worktree add ../x" /tmp/fixture
  allowed "cd /private/tmp/fixture && git worktree add ../x"
  allowed "git -C /var/folders/ab/T/fixture worktree add ../x"
}

@test "git worktree add passes in a folder the command does not spell out" {
  allowed 'cd "$(mktemp -d)" && git init -q && git worktree add ../x' "$work"
  allowed 'git -C "$fixture" worktree add ../x' "$work"
}

@test "other worktree commands and words inside quotes or heredocs pass" {
  allowed "git worktree list"
  allowed "git worktree remove ../x"
  allowed "orca worktree create --name x"
  allowed 'grep -rn "git worktree add" docs'
  allowed "echo 'never run git worktree add; git push --force origin main'"
  allowed "git commit -m \"docs: say why; git worktree add is blocked\""
  allowed "cat > notes.md <<'EOF'
git worktree add ../x
git push --force origin main
EOF"
}

@test "a force-push that names main is blocked and the message says what to do" {
  blocked "git push --force origin main"
  [[ "$output" == *'git revert <commit>'* && "$output" == *'git push --force-with-lease origin <branch>'* ]]
  blocked "git push -f origin HEAD:main"
  blocked "git push --force-with-lease origin feature main"
  blocked "git push -uf origin refs/heads/master"
  blocked "git push origin +main"
  blocked "git push origin feature +HEAD:refs/heads/main"
  blocked "git push --force --all"
  blocked "git push --force \\
  origin main # as asked"
}

@test "a force-push without a branch is blocked when the checkout is on main" {
  blocked "git push --force"
  blocked "git push -f origin"
  blocked "git push -f origin HEAD"
  other="$HOME/projects/other"
  new_repo "$other"
  blocked "cd $other && git push -f" "$HOME"
  blocked "git -C $other push -f" "$HOME"
}

@test "a force-push of another branch passes" {
  allowed "git push --force-with-lease origin feature"
  allowed "git push -f origin feature:feature"
  allowed "git push origin +feature main"
  allowed "git push -f origin feature # never main"
  allowed "git push --force-with-lease origin feature  # not on main; see #12"
  git -C "$repo" checkout -q -b feature
  allowed "git push --force"
  allowed "git push -f origin HEAD"
}

@test "a push without force passes, also to main" {
  allowed "git push"
  allowed "git push origin main"
  allowed "git push -u origin main"
  allowed "git push --follow-tags origin main"
}

@test "a commit message that is not a conventional commit is blocked with an example" {
  blocked 'git commit -m "wip"'
  [[ "$output" == *'starts with "wip"'* && "$output" == *'fix: keep the queue file when ingest fails'* ]]
  blocked "git commit -am 'Added the login page'"
  blocked 'git commit --message="feat add login"'
  blocked 'git commit -m "feat:no space"'
  blocked 'git commit -m "Feat: capital type"'
  blocked "git add -A && git commit -m \"\$(cat <<'EOF'
Update the hook

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)\""
}

@test "a conventional commit message passes" {
  allowed 'git commit -m "feat: add the login page"'
  allowed 'git commit -am "fix(board)!: keep a completed card"'
  allowed "git commit --message='docs: say \"hi\"' -m 'a body that is free text'"
  allowed "git -C $repo commit -qm 'chore: start'"
  allowed "git add -A && git commit -m \"\$(cat <<'EOF'
test: cover the \"quoted\" case

A body; with git push --force origin main in it.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)\""
}

@test "a commit message in a file is checked when the file is there" {
  printf 'wip\n\nbody\n' > "$repo/bad.txt"
  printf '\nfeat: add the login page\n\nbody\n' > "$repo/good.txt"
  blocked "git commit -F bad.txt"
  [[ "$output" == *'starts with "wip"'* ]]
  blocked "cd $repo && git commit --file=bad.txt" "$HOME"
  blocked "git commit -F $repo/bad.txt" "$HOME"
  allowed "git commit -F good.txt"
  allowed "git commit -F not-written-yet.txt"
}

@test "a message file without text in its first 4096 bytes passes; git refuses an empty message itself" {
  printf '%5000s\nwip\n' ' ' > "$repo/spaces.txt"
  : > "$repo/empty.txt"
  allowed "git commit -F spaces.txt"
  allowed "git commit -F empty.txt"
}

@test "the message shows at most 200 characters of the first line, without control characters" {
  printf 'wip \033]0;title\007%300s end\n' ' ' > "$repo/odd.txt"
  blocked "git commit -F odd.txt"
  [[ "$output" == *'starts with "wip ]0;title '* && "$output" != *$'\033'* && "$output" != *" end"* ]]
}

@test "a command of more than 12,000 characters passes and the hook says that nothing was checked" {
  run agent_runs "git worktree add ../x; echo $(printf 'a %.0s' {1..6000})" "$work"
  is "$status" 1
  [[ "$output" == "check-command: the command is longer than 12,000 characters, so no rule was checked"* ]]
}

@test "a commit whose message the command does not spell out passes" {
  allowed 'git commit -m "$message"'
  allowed 'git commit -m "$(./make-message)"'
  allowed "git commit --amend --no-edit"
  allowed "git commit"
  allowed "git commit -F -"
  allowed 'git commit --fixup HEAD~1 -m "more"'
}

@test "messages git writes itself pass" {
  allowed "git commit -m 'Merge branch main into feature'"
  allowed "git commit -m 'Revert \"feat: add the login page\"'"
  allowed "git commit -m 'fixup! feat: add the login page'"
}

@test "a command without git passes, and so do other git commands" {
  allowed "ls -la"
  allowed "git status && git log --oneline -5"
  allowed "gh pr create --title 'wip'"
}

@test "input that is not JSON lets the call pass and says that nothing was checked" {
  run bash -c 'echo "git worktree add, but not JSON" | "$1"' _ "$kit/hooks/check-command.sh"
  is "$status" 1
  [[ "$output" == "check-command: the hook input is not the JSON a Bash call sends, so no rule was checked"* ]]
}

@test "input without a command lets the call pass and says that nothing was checked" {
  run bash -c 'echo "{\"tool_name\": \"Bash\", \"note\": \"git\"}" | "$1"' _ "$kit/hooks/check-command.sh"
  is "$status" 1
  [[ "$output" == "check-command: the hook input is not the JSON a Bash call sends"* ]]
}

@test "the installed settings run the hook before Bash calls" {
  merged=$(echo '{}' | jq --arg kit /kit --argjson skills '[]' --slurpfile fragment "$kit/claude/settings.fragment.json" -f "$kit/claude/merge-settings.jq")
  is "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' <<<"$merged")" "/kit/hooks/check-command.sh"
  again=$(jq --arg kit /kit --argjson skills '[]' --slurpfile fragment "$kit/claude/settings.fragment.json" -f "$kit/claude/merge-settings.jq" <<<"$merged")
  is "$again" "$merged"
}
