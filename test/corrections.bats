#!/usr/bin/env bats
# `wk corrections`: counts the sessions each correction record was seen in, and says which reached three.

# shellcheck disable=SC2154 # kit and the helpers come from helpers.bash
load helpers

setup() {
  setup_home
  adopted_project
}

# record <key> <layer> <session>...: a correction record seen in those sessions; each session summary is created.
record() {
  local key="$1" layer="$2" session
  shift 2
  mkdir -p knowledge-base/wiki/corrections
  {
    printf -- '---\ntype: correction\nupdated: 2026-01-01\nlayer: %s\nsources:\n' "$layer"
    for session in "$@"; do
      touch "knowledge-base/raw/sessions/$session.md"
      printf '  - raw/sessions/%s.md\n' "$session"
    done
    printf -- '---\n# %s\n' "$key"
  } > "knowledge-base/wiki/corrections/$key.md"
}

corrections() { "$kit/bin/wk" corrections | tr '\t' ' '; }

@test "a vault without correction records prints nothing" {
  run "$kit/bin/wk" corrections
  [ "$status" -eq 0 ]
  is "$output" ""
}

@test "a correction seen in two sessions is waiting" {
  record uv-not-pip check s1 s2
  is "$(corrections)" "waiting uv-not-pip 2 check -"
}

@test "a correction seen in three sessions is due" {
  record uv-not-pip check s1 s2 s3
  is "$(corrections)" "due uv-not-pip 3 check -"
}

@test "the same session listed twice counts once" {
  record uv-not-pip check s1 s2 s2
  is "$(corrections)" "waiting uv-not-pip 2 check -"
}

@test "a source that is not a session summary is not counted" {
  record uv-not-pip prose s1 s2
  touch knowledge-base/raw/inbox/note.md
  sed -i '' 's|^sources:$|sources:\
  - raw/inbox/note.md|' knowledge-base/wiki/corrections/uv-not-pip.md
  is "$(corrections)" "waiting uv-not-pip 2 prose -"
}

@test "every record gets its own line" {
  record a-first check s1 s2 s3
  record b-second prose s1
  is "$(corrections)" "due a-first 3 check -
waiting b-second 1 prose -"
}

@test "a session summary that does not exist makes the record broken, and the line says how to fix it" {
  record uv-not-pip check s1 s2 s3
  rm knowledge-base/raw/sessions/s3.md
  run corrections
  [[ "$output" == "broken uv-not-pip 2 check raw/sessions/s3.md is not a session summary in the vault;"* ]]
}

@test "a layer that is not one of the four makes the record broken" {
  record uv-not-pip hook s1 s2 s3
  run corrections
  [[ "$output" == "broken uv-not-pip 3 hook layer must be design, check, proof or prose"* ]]
}

@test "a record without a layer is broken" {
  record uv-not-pip check s1
  sed -i '' '/^layer:/d' knowledge-base/wiki/corrections/uv-not-pip.md
  run corrections
  [[ "$output" == "broken uv-not-pip 1 - layer must be"* ]]
}

@test "a file name that is not a plain key makes the record broken" {
  record "Uv_Not pip" check s1
  run corrections
  [[ "$output" == "broken Uv_Not pip 1 check the file name must be"* ]]
}

@test "a commit with the correction's trailer makes it done, and the line names the commit" {
  record uv-not-pip check s1 s2 s3
  git commit -q --allow-empty -m "test: uv, not pip" -m "Correction: uv-not-pip"
  is "$(corrections)" "done uv-not-pip 3 check $(git rev-parse --short HEAD)"
}

@test "the commit counts on any branch, also after a revert" {
  record uv-not-pip check s1 s2 s3
  git checkout -q -b other
  echo check > check.txt
  git add check.txt
  git commit -q -m "test: uv, not pip" -m "Correction: uv-not-pip"
  sha=$(git rev-parse --short HEAD)
  git revert --no-edit HEAD > /dev/null
  git checkout -q main
  is "$(corrections)" "done uv-not-pip 3 check $sha"
}

@test "a trailer inside a squashed commit message still counts" {
  record uv-not-pip check s1 s2 s3
  git commit -q --allow-empty -m "feat: many things (#7)" -m "* test: uv, not pip

    Correction: uv-not-pip"
  [[ "$(corrections)" == "done uv-not-pip 3 check "* ]]
}

@test "the trailer of a longer or shorter key does not count" {
  record uv-not-pip check s1 s2 s3
  git commit -q --allow-empty -m "test: a" -m "Correction: uv-not-pip-ever"
  git commit -q --allow-empty -m "test: b" -m "Correction: no-uv-not-pip"
  is "$(corrections)" "due uv-not-pip 3 check -"
}

@test "outside a project the command says so and fails" {
  cd "$HOME"
  run "$kit/bin/wk" corrections
  [ "$status" -eq 1 ]
  [[ "$output" == "wk corrections: "*"run it inside a project"* ]]
}

@test "two summaries of one resumed session count once" {
  record uv-not-pip check 2026-01-01-demo-aaaa1111 2026-01-02-demo-aaaa1111 2026-01-03-demo-bbbb2222
  is "$(corrections)" "waiting uv-not-pip 2 check -"
}

@test "a source path that leaves raw/sessions makes the record broken" {
  record uv-not-pip check s1 s2 ../../wiki/overview
  run corrections
  [[ "$output" == "broken uv-not-pip 2 check raw/sessions/../../wiki/overview.md is not a session summary"* ]]
}

@test "sources written on one line make the record broken, and the line shows the form" {
  record uv-not-pip check s1 s2 s3
  printf -- '---\nlayer: check\nsources: [raw/sessions/s1.md, raw/sessions/s2.md, raw/sessions/s3.md]\n---\n' \
    > knowledge-base/wiki/corrections/uv-not-pip.md
  run corrections
  [[ "$output" == "broken uv-not-pip 0 check the frontmatter lists no session summary; "*'`  - raw/sessions/<file>.md`'* ]]
}

@test "quoted values and Windows line ends are read like plain ones" {
  record uv-not-pip check s1 s2 s3
  printf -- '---\r\nlayer: "check"\r\nsources:\r\n  - "raw/sessions/s1.md"\r\n  - raw/sessions/s2.md\r\n  - raw/sessions/s3.md\r\n---\r\n' \
    > knowledge-base/wiki/corrections/uv-not-pip.md
  is "$(corrections)" "due uv-not-pip 3 check -"
}

@test "a tab in a file name does not shift the columns" {
  record "a$(printf '\t')b" check s1
  run corrections
  [[ "$output" == "broken a b 1 check the file name must be"* ]]
}

@test "a session newer than the check's commit makes the correction due again, and the line names the commit" {
  record uv-not-pip check 2026-01-01-demo-aaaa1111 2026-01-02-demo-bbbb2222 2026-01-03-demo-cccc3333
  GIT_COMMITTER_DATE="2026-01-04T12:00:00Z" git commit -q --allow-empty -m "test: uv, not pip" -m "Correction: uv-not-pip"
  sha=$(git rev-parse --short HEAD)
  is "$(corrections)" "done uv-not-pip 3 check $sha"
  record uv-not-pip check 2026-01-01-demo-aaaa1111 2026-01-02-demo-bbbb2222 2026-01-03-demo-cccc3333 2026-01-09-demo-dddd4444
  is "$(corrections)" "due uv-not-pip 4 check after $sha"
  GIT_COMMITTER_DATE="2026-01-10T12:00:00Z" git commit -q --allow-empty -m "test: catch pip in scripts too" -m "Correction: uv-not-pip"
  is "$(corrections)" "done uv-not-pip 4 check $(git rev-parse --short HEAD)"
}

@test "several due records are matched to their own commits" {
  record a-first check s1 s2 s3
  record b-second prose s1 s2 s3
  record c-third check s1 s2 s3
  git commit -q --allow-empty -m "docs: b" -m "Correction: b-second"
  is "$(corrections)" "due a-first 3 check -
done b-second 3 prose $(git rev-parse --short HEAD)
due c-third 3 check -"
}

@test "in a linked worktree the records of the primary checkout are counted, and a commit on its branch counts" {
  record uv-not-pip check s1 s2 s3
  git worktree add -q -b ticket "$HOME/projects/demo-ticket"
  cd "$HOME/projects/demo-ticket"
  is "$(corrections)" "due uv-not-pip 3 check -"
  git commit -q --allow-empty -m "test: uv, not pip" -m "Correction: uv-not-pip"
  cd "$project"
  [[ "$(corrections)" == "done uv-not-pip 3 check "* ]]
}
