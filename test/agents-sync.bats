#!/usr/bin/env bats
# `wk agents-sync`: pinned agents may carry a recorded patch, and the lock file records the result.

# shellcheck disable=SC2154 # kit, state and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  source_repo="$HOME/upstream"
  new_repo "$source_repo"
  mkdir "$source_repo/agents"
  printf -- '---\nname: reviewer\n---\nReview the code.\nBe kind.\n' > "$source_repo/agents/reviewer.md"
  git -C "$source_repo" add -A
  git -C "$source_repo" commit -q -m "feat: reviewer"
  printf '[source]\nrepo = "%s"\ncommit = "%s"\n\n[agents]\nreviewer = { skills = [] }\n' \
    "$source_repo" "$(git -C "$source_repo" rev-parse HEAD)" > "$HOME/kit/agents/agents.toml"
  lock="$HOME/kit/agents/agents.lock"
  installed="$HOME/.claude/agents/ecc/reviewer.md"
}

# patch_reviewer <old last line> <new last line>: a recorded patch for the agent reviewer.
patch_reviewer() {
  mkdir -p "$HOME/kit/patches/agents"
  printf -- '--- a/reviewer.md\n+++ b/reviewer.md\n@@ -4,2 +4,2 @@\n Review the code.\n-%s\n+%s\n' "$1" "$2" > "$HOME/kit/patches/agents/reviewer.patch"
}

@test "an agent is installed from its pin and recorded in the lock file" {
  run "$kit/bin/wk" agents-sync
  [ "$status" -eq 0 ]
  is "$(tail -1 "$installed")" "Be kind."
  is "$(jq -r '.agents.reviewer | .upstream_sha256 == .installed_sha256' "$lock")" true
}

@test "a recorded patch is applied and the lock file holds the checksum before and after" {
  "$kit/bin/wk" agents-sync
  unpatched=$(jq -r '.agents.reviewer.installed_sha256' "$lock")
  patch_reviewer "Be kind." "Be kind and brief."
  run "$kit/bin/wk" agents-sync
  [ "$status" -eq 0 ]
  is "$(tail -1 "$installed")" "Be kind and brief."
  is "$(jq -r '.agents.reviewer.upstream_sha256' "$lock")" "$unpatched"
  is "$(jq -r '.agents.reviewer.installed_sha256' "$lock")" "$(shasum -a 256 "$installed" | cut -d' ' -f1)"
  is "$(jq -r '.agents.reviewer.patch_sha256' "$lock")" "$(shasum -a 256 < "$HOME/kit/patches/agents/reviewer.patch" | cut -d' ' -f1)"
  [[ "$output" == *"patched reviewer"* ]]
}

@test "with a patch, a second run changes nothing" {
  patch_reviewer "Be kind." "Be kind and brief."
  "$kit/bin/wk" agents-sync
  before="$(cat "$lock") $(cat "$installed")"
  "$kit/bin/wk" agents-sync
  is "$(cat "$lock") $(cat "$installed")" "$before"
}

@test "a patch that no longer applies fails and names the agent and the patch" {
  patch_reviewer "a line upstream no longer has" "anything"
  run "$kit/bin/wk" agents-sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"agent reviewer:"*"patches/agents/reviewer.patch no longer applies"* ]]
}

@test "a patch that stops applying leaves the installed agent and the lock file as they were" {
  "$kit/bin/wk" agents-sync
  before="$(cat "$lock") $(cat "$installed")"
  patch_reviewer "a line upstream no longer has" "anything"
  run "$kit/bin/wk" agents-sync
  [ "$status" -ne 0 ]
  is "$(cat "$lock") $(cat "$installed")" "$before"
}

@test "a removed patch brings the upstream text back" {
  patch_reviewer "Be kind." "Be kind and brief."
  "$kit/bin/wk" agents-sync
  rm "$HOME/kit/patches/agents/reviewer.patch"
  "$kit/bin/wk" agents-sync
  is "$(tail -1 "$installed")" "Be kind."
  is "$(jq -r '.agents.reviewer | has("patch_sha256")' "$lock")" false
}

@test "an agent installed into a project carries its patch too" {
  patch_reviewer "Be kind." "Be kind and brief."
  mkdir "$HOME/projects/demo"
  "$kit/bin/wk" agents-sync --project "$HOME/projects/demo" reviewer
  is "$(tail -1 "$HOME/projects/demo/.claude/agents/reviewer.md")" "Be kind and brief."
}

@test "a patch that was never applied is a doctor gap" {
  "$kit/bin/wk" agents-sync
  adopted_project
  "$kit/bin/wk" doctor > /dev/null
  patch_reviewer "Be kind." "Be kind and brief."
  run "$kit/bin/wk" doctor
  [[ "$output" == "patches: patches/agents/reviewer.patch is not applied"* ]]
}

@test "after a sync the doctor sees no difference in the agents" {
  patch_reviewer "Be kind." "Be kind and brief."
  "$kit/bin/wk" agents-sync
  adopted_project
  "$kit/bin/wk" doctor > /dev/null
  is "$("$kit/bin/wk" doctor)" ""
}
