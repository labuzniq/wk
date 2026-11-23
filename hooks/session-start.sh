#!/usr/bin/env bash
# Adds capsule gaps and a short project context to the session. Must stay fast: no network, no waiting on Orca.
kit="$(dirname "$0")/.."
cd "$(jq -r '.cwd')" 2>/dev/null || exit 0
# shellcheck source=../lib/config.sh
. "$kit/lib/config.sh"
declined="$HOME/.local/state/workspace-kit/declined/$(printf '%s' "$PWD" | shasum | cut -d' ' -f1)"
setup='run `wk adopt` in this folder, commit the files it creates, and tell the user in one line that the project is now set up. Then handle their request.'

# shellcheck source=../lib/project.sh
if ! . "$kit/lib/project.sh"; then
  case "$PWD/" in "$(wk_config projects_root)"/*) echo "New project folder without a workspace-kit capsule. Before anything else, $setup" ;; esac
  exit 0
fi

if [ ! -f "$manifest" ]; then
  offer="$state_dir/capsule-pr/$(path_key "$primary")"
  if [ -z "$(git rev-list -n 1 --all 2>/dev/null)" ]; then
    echo "New repo without a workspace-kit capsule. Before anything else, $setup"
  elif [ -f "$primary/.workspace-kit.toml" ]; then
    rm -f "$offer" # the capsule is merged and pulled; this checkout gets it with its next rebase
  elif [ -f "$offer" ]; then
    nohup "$kit/bin/wk" adopt-pr --refresh >/dev/null 2>&1 &
    url=$(sed -n 2p "$offer")
    if [ "$(sed -n 3p "$offer")" = MERGED ] && [[ "$url" =~ ^https://github\.com/[^/]+/[^/]+/pull/[0-9]+$ ]]; then
      echo "The capsule pull request $url is merged, but the main checkout does not have it yet. Update the default branch in $primary (\`git pull --ff-only\`), then run \`wk adopt\` there to finish the setup."
    fi
  elif [ -f "$declined" ] || [ -f "$state_dir/declined/$(path_key "$primary")" ]; then
    :
  elif [[ "$(git config --get remote.origin.url)" =~ ^(https://|ssh://git@|git@)github\.com[:/] ]]; then
    echo "This existing repo has no workspace-kit capsule. Before anything else, run \`wk adopt-pr\`: it puts the capsule on a branch and prints the URL of a pull request. Tell the user in one line that the capsule is offered as that pull request, and that closing it means no. If it prints a question for the user instead, ask it. Then handle their request."
  else
    echo "This existing repo has no workspace-kit capsule. Ask the user once, yes or no, whether to set it up. On yes, $setup On no, run \`wk adopt-pr --decline\` so the question is never asked again."
  fi
  exit 0
fi

repo_stamp="$state_dir/repo-sync/$(path_key "$primary")"
mkdir -p "$(dirname "$repo_stamp")"
if [ ! -f "$repo_stamp" ] || [ $(( $(date +%s) - $(stat -f %m "$repo_stamp") )) -ge 3600 ]; then
  touch "$repo_stamp"
  nohup "$kit/bin/wk" board-sync --repo >/dev/null 2>&1 &
fi
nohup "$kit/bin/wk" board-sync >/dev/null 2>&1 &

card="main checkout"
if [ "$root" != "$primary" ]; then
  card=$(jq -r '.result.worktree | "\(.displayName) [\(.workspaceStatus)]\n\(.comment // "" | .[0:600])"' "$state_dir/cards/$(path_key "$root").json" 2>/dev/null) \
    || card="not cached yet; read it with \`orca worktree current --json\`"
fi
vision=$(cd "$root" && ls VISION.md 2>/dev/null || echo "none yet")
# shellcheck disable=SC2012 # newest by time; spec names are plain
spec=$(cd "$root" && ls -t docs/specs/*.md 2>/dev/null | head -1)

cat <<CONTEXT
Project: $(manifest_value slug) ($(manifest_value type))
Orca card: $card
Vision: $vision
Vault: $(vault_dir) (project page: wiki/overview.md)
Newest spec: ${spec:-none yet}
CONTEXT

gaps=$("$kit/bin/wk" doctor)
if [ -n "$gaps" ]; then
  printf '\nCapsule gaps:\n%s\n\nLoad the `project-setup` skill and fix every gap yourself now, without asking. A gap that says "needs the user" waits until their request is handled.\n' "$gaps"
fi
