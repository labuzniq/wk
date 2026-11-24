# Verified facts

Build record of this kit on one Mac. Section numbers such as "3.2" point at the private build spec the kit was made from.

Checked on 2026-11-23. Orca 1.4.271, Claude Code 2.1.311, macOS.

Result words: **confirmed** (tested on this Mac), **docs** (read in official docs, not tested), **open** (needs the owner).

## Checks V1 to V12

| # | Result | Finding |
|---|---|---|
| V1 | confirmed | Setup commands can live in the repo file. `orca.yaml` with `scripts.setup` ran when a worktree was created with `--setup run`. The repo's policy is `setupRunPolicy: run-by-default`, so `--setup inherit` also runs it. The script gets `ORCA_ROOT_PATH` (primary checkout) and `ORCA_WORKTREE_PATH`. The public docs only describe `worktree.sharedDirectories`; `scripts.setup` is used by Orca's own `orca.yaml`. |
| V2 | confirmed | Worktrees go to `~/orca/workspaces/<repo-name>/<worktree-name>`. The branch gets the git user prefix: `<git user>/<name>`. Worktree id format: `<repoId>::<path>`. |
| V3 | confirmed by CLI (Command Line Interface), board look is open | `orca worktree set --workspace-status` stored and read back `todo`, `in-progress`, `in-review`, `completed` on a local card. Nobody has looked at the board itself yet. Card `wk-scratch` is left in place for that. |
| V4 | confirmed | A new worktree starts as `in-progress`, not `todo`. |
| V5 | open | No setting named "Sync board status with agent turns" in the docs or in Orca's local settings files. Needs a look in the Workspace Board settings menu. |
| V6 | docs | `WorktreeCreate` input: common fields (`session_id`, `transcript_path`, `cwd`) plus `name`. The hook replaces the git default and must print the path as the last non-empty stdout line; non-zero exit fails the creation. `WorktreeRemove` input: `worktree_path`. `SessionEnd` input: `reason`; default budget 1.5 seconds. `PreCompact` input: `trigger` (`manual` or `auto`). `SessionStart` input: `source` (`startup`, `resume`, `clear`, `compact`, `fork`); stdout becomes context, capped at 10,000 characters. |
| V7 | docs | A subagent **can** spawn subagents, up to three layers deep. |
| V8 | confirmed | `disable-model-invocation: true` on: `ask-matt`, `grill-me`, `grill-with-docs`, `implement`, `improve-codebase-architecture`, `teach`, `to-questionnaire`, `to-spec`, `to-tickets`, `triage`, `wait-what`, `wayfinder`. Model-invocable: `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grilling`, `orca-cli`, `orca-computer-use`, `orchestration`, `prototype`, `research`, `resolving-merge-conflicts`, `tdd`, `wizard`, `writing-for-agents`. |
| V9 | confirmed | `npx skills add <package> -g -a claude-code -s <skill> -y` installs straight into `~/.claude/skills/<name>` as a copy. Tested against a sandbox home folder. |
| V10 | open | Docs do not say whether automations fire while Orca is closed. A test needs Orca to be quit, which would stop running sessions. |
| V11 | confirmed | No selected agent depends on an ECC-only thing to run. Five bodies hold "see also" pointers to things missing here (list below). ECC main was at commit `4adeee6732a12d1540f49a4d50a38ce8c97f9a53`. |
| V12 | docs | `permissions.additionalDirectories` is current. Bash rule form `Bash(orca *)` is current. Hook shape `hooks.<Event>[].{matcher, hooks:[{type, command, timeout}]}` is current. |

## V11 detail: pointers to things that do not exist here

| Agent | Pointer |
|---|---|
| `security-reviewer` | skill `security-review` |
| `python-reviewer` | skill `python-patterns` |
| `typescript-reviewer` | skills `typescript-patterns`, `coding-standards`, `frontend-patterns`, `backend-patterns`; command `/react-review`; agent `react-reviewer` |
| `swift-reviewer` | rules `swift/*`; skills `swift-concurrency-6-2`, `swiftui-patterns`, `swift-protocol-di-testing` |
| `swift-build-resolver` | rules `swift/*`; skills `swift-concurrency-6-2`, `swift-actor-persistence` |

None of these would make an agent fail, so no patch is planned.

## Other facts found

- `mise` is not installed.
- `~/.claude/skills` holds 23 real folders that are identical copies of the folders in `~/.agents/skills`. Only `orca-cli`, `orca-computer-use` and `orchestration` are symlinks.
- `vision`, `setup-matt-pocock-skills`, `retro`, `implement-spec`, `handoff`, `pr` are in neither skills folder.
- `~/.claude/agents` does not exist yet.
- `~/.claude/settings.json` already has Orca hooks on 16 events, including `SessionStart`, `Stop` and `SessionEnd`. `permissions` holds only `defaultMode`.
- Orca agent status hooks are on. Orca has 0 automations.
- `orca worktree rm` refuses `active`/`current`, needs the full id, and keeps the branch unless `--delete-branch` is passed. There is no `orca repo rm`, only `orca repo hide`.
- Wispr Flow notes are reachable through an MCP (Model Context Protocol) connector in the Claude desktop app session. Not checked: whether sessions started by Orca automations have the same connector.

## Where reality differs from the spec

| Spec | Reality | What the kit will do |
|---|---|---|
| 3.2 #5: setup command typed by hand in Orca Settings per repository | `orca.yaml` `scripts.setup` works | The capsule template carries `scripts.setup`. The manual step and the marker file go away; the `orca_setup_hook` check reads `orca.yaml`. |
| 5.2 implies a new card may be `todo` | New cards start `in-progress` | Replaced on 2026-11-23: tickets are issues, see the last section. |
| 4.2: do not preload `code-review` because subagents cannot fan out | Subagents can spawn subagents | Keep `code-review` in the main session anyway; the stated reason no longer holds. |
| 4.5: no skill covers security review | Claude Code ships a built-in `security-review` skill | Nothing added. The owner decides. |
| 1.3 step 5: skip skill names that are real folders | 23 of 26 are real folders (identical copies) | Skip and report them, unless the owner wants them swapped for symlinks. |
| 6.2: `mise` tasks | `mise` missing | `install.sh` does not need `mise`. The doctor (Phase 5) reports it as a gap. |
| 0.2: one vault path | Answer was "per-project individual setup" | Decided: one vault per project. Default place is `knowledge-base/` inside the project repo; `.workspace-kit.toml` at the repo root holds the path. No `vault` key in the global config, no vault in the global `additionalDirectories`, one ingest automation per project. |
| 1.1: kit at `~/workspace-kit` | The owner chose `~/.workspace-kit` | Used as given. |

## Inputs (section 0.2)

| Input | Value |
|---|---|
| Vault | one per project, path in `.workspace-kit.toml` |
| Projects root | `~/Workspace` |
| Kit location | `~/.workspace-kit` |
| Wispr Flow | reachable through MCP in the desktop app |
| First project | a private TypeScript and Swift project |

## Decisions after Phase 1

- Files the kit invents live outside `.claude`. The project manifest is `.workspace-kit.toml` at the repo root (the spec had `.claude/project.toml`). `.claude/` holds only what Claude Code itself reads: `settings.json`, `agents/`, `skills/`.
- Skills are installed into the shared `~/.agents/skills` folder and linked into `~/.claude/skills` (`npx skills add <package> -g -a universal -a claude-code -s <skill> -y`). `skills.txt` lists every third-party skill.
- Clean reinstall on 2026-11-23: every skill in `~/.agents/skills` was moved to `~/.claude/backup/20261123-171507-skills/` and installed fresh from its source. `resolving-merge-conflicts` is no longer published in `mattpocock/skills`, so the existing copy was kept. `codebase-to-course`, `find-skills` and `synced` in `~/.claude/skills` are not kit skills and were left alone.
- After the reinstall, `disable-model-invocation: true` is also set on the new skills `handoff`, `implement-spec`, `retro` and `setup-matt-pocock-skills`. `pr` is model-invocable. `codebase-design`, `diagnosing-bugs` and `tdd` are still model-invocable, so the agent skill mapping in section 4.2 holds.

## Phase 4 results (2026-11-23)

- A subagent started with `isolation: worktree` got its worktree at `~/orca/workspaces/.workspace-kit/agent-<id>`, as an Orca card. No `.claude/worktrees` folder was created.
- Claude Code did not call the `WorktreeRemove` hook when that subagent finished, so the card stayed until the hook was run by hand. When the hook fires on its own is not yet known.
- `wk board-sync` tested on scratch cards: new card stays `todo`; uncommitted file or a commit moves `todo` to `in-progress`; a merge commit into the base moves it to `completed`; a merge into another branch does not. Open, changes-requested and merged pull requests were tested with a stand-in for `gh`, not with a real pull request (the kit repo has no GitHub remote).
- "Has commits of its own and all contained in base" is checked as: the branch tip is reachable from the base, and is not on the base's first-parent line. A fast-forward or squash merge is therefore only seen through the pull request state.
- `gh` is asked only when the branch exists on `origin`, and at most once per 10 minutes per worktree.

## Phase 5 results (2026-11-23)

- `setup-matt-pocock-skills` stores its tracker choice in `docs/agents/issue-tracker.md`; the `matt_setup` check looks for that file.
- The `vision` skill may write the vision into `STRATEGY.md` instead of `VISION.md`; the `vision` check accepts either. It did so in this repo, because no `VISION.md` existed; on 2026-11-23 the file was renamed to `VISION.md`, which is where the global instructions and the session-start hook look.
- `orca worktree current --json` takes about 1 second, too slow for the session-start hook. `wk board-sync` saves the card to `~/.local/state/workspace-kit/cards/`, and the hook reads that copy. The first session in a new worktree shows "not cached yet".
- Doctor and session-start hook each ran in under 0.5 seconds on the demo project.
- `orca_repo` passes when `orca_repo_id` is set in `.workspace-kit.toml` (no Orca call). `orca_setup_hook` passes when `orca.yaml` has `scripts.setup` (no marker file).
- No `.claude/settings.json` is created per project: the vault is inside the repo, so there is no project-specific permission to add.

## Phase 6 results (2026-11-23)

- Vault is one per project, in `knowledge-base/` inside the project repo. The ingest and lint sessions therefore run with the project root as their folder, so the spec's "skip when the folder is inside the vault" guard is not enough. Each of the two skills first writes a marker file named after its own session id; the queue hook skips any session with a marker.
- The queue is per project: `~/.local/state/workspace-kit/sessions/<slug>/queue/`.
- Each project gets its own two automations, `Wiki ingest: <slug>` and `Wiki lint: <slug>`, created by `wk adopt` with `--workspace path:<project root>`.
- The ingest precheck passes when the queue has files, or when git shows new or changed files under the vault's `raw/` folder.
- A session in a worktree reaches the vault of the primary checkout through `.claude/settings.local.json` (`permissions.additionalDirectories`). That file is gitignored and listed in `.worktreeinclude`, so Orca copies it into each new worktree.
- The queue hook ran in 0.4 seconds; the `SessionEnd` budget is 1.5 seconds.

## Change of direction after Phase 7 (2026-11-23)

The owner: setup and the spec flow must run without typed commands. This replaces two spec rules ("flow skills are user-invoked; recommend them" and "the doctor tells me what to type").

- Global `CLAUDE.md`, Lifecycle: the agent picks the step from `ask-matt` and runs each flow skill itself by reading its `SKILL.md`, user-invoked skills included. The skill files stay untouched.
- `wk adopt` needs no flags: it detects the stack, fits `mise.toml` to the repo (npm or pnpm from the lockfile, lint script from `package.json`, Node version from `.nvmrc`), starts git in a plain folder, and writes `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md` and the `## Agent skills` block in `CLAUDE.md`. This is what `/setup-matt-pocock-skills` would have produced, so that command is no longer needed.
- Session start: in a new folder or empty repo the agent runs `wk adopt` at once. In an existing repo with history it asks once, yes or no; a "no" is remembered in `~/.local/state/workspace-kit/declined/`.
- Gaps: the agent fixes them without asking. Only `vision`, `vision_fresh` and `proposals` need the user, and they are raised after the user's request is handled.
- `orca.yaml` no longer shares `node_modules` between worktrees; each worktree installs its own.
- `~/.claude/settings.json` had a `skillOverrides` block that switched 25 kit skills "off", which hid them from the slash menu and from the model. `install.sh` now removes the override for every skill the kit installs.

## Tickets are issues, not workspaces (2026-11-23)

The first real use of `to-tickets` created 16 empty workspaces and no issue. Orca's own model: a ticket is an issue (GitHub, GitLab, Linear or Jira, shown in its Issues view), and a workspace is a worktree linked to one with `orca worktree create --issue <number>`.

- `wk adopt` now writes `docs/agents/issue-tracker.md` from the tracker doc that `setup-matt-pocock-skills` ships for the repo's remote (GitHub, GitLab, or local files when there is no such remote), followed by the kit's `templates/orca-workspaces.md`.
- A workspace is created when work on a ticket starts, never to hold a ticket.
- `wk doctor` has a `tracker` check that reports a tracker doc of the old kind.

## Kit test harness (2026-11-23)

- confirmed: `test/run` runs shell lint, Python lint and the tests on this Mac. The tests cover the board status rules, the doctor's gap lines, the session queue hook, and `wk adopt` plus `wk doctor` on a scratch project.
- confirmed: the CI (Continuous Integration) run on GitHub passed on pull request #20, in about 1 minute on a macOS runner.
- The tests use stand-ins for `orca` and `gh` (`test/stubs/`), so "Orca answers this way" is assumed from the checks above, not tested again.
- Found by the tests: on a machine without `~/.agents/skills`, the doctor reported `skills_visible: * is not visible to Claude Code`. Fixed.
- Stock macOS has bash 3.2, which has no `mapfile`; the kit's scripts stay within bash 3.2.
- CI runs on a macOS runner, because the scripts use the macOS form of `stat` (`stat -f %m`).

## Recorded patches and skill pins (2026-11-23)

- confirmed: `npx skills add owner/repo#<commit>` installs the skill as it was at that commit. Tested in a sandbox home with an older commit of `mattpocock/skills`; the files differed from the newest ones and `.skill-lock.json` recorded the older commit.
- confirmed: installing a skill again replaces its folder, so hand edits and files added by hand are gone.
- confirmed: asking for a skill the package does not hold exits 0 and installs nothing. `wk skills-sync` therefore checks that the folder exists.
- confirmed: `skills.lock` was written from a sandbox home, and the 28 skills installed on this Mac have the same checksum.
- confirmed: the doctor's new `skills` check takes about 0.03 seconds for 28 skills.
- confirmed: Apple's `patch` (2.0-12u11) leaves a `.orig` file when a hunk applies at shifted line numbers, and an empty file when a patch deletes one. The kit calls it with `--no-backup-if-mismatch -E`. It also follows `../` in a patch path, so the kit refuses such a patch before calling it.
- The installer is called as `npx skills@1.9.0`, the version these facts were tested with.
- A skill that differs from what the lock file can bring back is moved to `~/.claude/backup/<timestamp>-skills/` before it is installed again.
- No patch ships yet: check V11 found no skill or agent that needs one. The tests apply a patch to a stand-in skill and a stand-in agent.
- `wk skills-sync` and `wk agents-sync` are tested with stand-ins for `npx` and for the upstream repo, not against the network.

## Capsule by pull request (2026-11-23)

This replaces "in an existing repo with history it asks once" from the change of direction above, for repos whose `origin` is on github.com and that belong to the signed-in `gh` user. A repo without a GitHub remote is still asked about once. A repo on GitHub that belongs to someone else (an employer, an open-source project) is asked about once too, because a branch and a pull request there are seen by other people; on yes the agent runs `wk adopt-pr --confirmed`.

- `wk adopt-pr` creates the Orca worktree `workspace-kit-capsule`, runs `wk adopt` in it, pushes the branch and opens the pull request. A run that stopped half way can be run again: it takes over the worktree, the branch and an open pull request.
- The offer is remembered in `~/.local/state/workspace-kit/capsule-pr/` (four lines: number, URL, state, worktree path).
- The session-start hook makes no network call: it reads that file and starts `wk adopt-pr --refresh` in the background. A closed pull request becomes a file in `declined/`, the same place an old "no" lives, and its card is completed.
- `wk adopt` in a worktree whose main checkout has no capsule yet creates files only. The Orca automations and the vault permission in the main checkout are created by `wk adopt` there after the merge; the doctor's `automations` gap asks for it. The doctor reads a marker file, not Orca. A project adopted before this change shows that gap once, until `wk adopt` writes the marker.
- Before the merge, Orca already knows the repo (`orca repo add`, `orca repo set-base-ref`): a worktree cannot be created without it.
- confirmed with stand-ins for `orca` and `gh`. The Orca and gh calls it makes (`orca worktree create --repo --name --no-parent --setup skip --comment --json`, `orca worktree set --pr --workspace-status`, `gh pr create`, `gh pr view --json state`, `gh pr list --head`, `gh repo view --json owner`, `gh api user`) were each used by hand on this Mac the same day or are read in `--help`.
- open: one whole run of `wk adopt-pr` against a real repo on GitHub.

## Pin update (2026-11-23)

- confirmed: `git ls-remote <repo> HEAD` names the newest commit of the three sources. Run against the real kit repo, `wk pins-update --dry-run` printed "every pin is at the newest upstream commit; no pull request" in 2 seconds.
- confirmed: a full dry run with the real upstream repos and the real `npx skills@1.9.0`. A throwaway kit was pinned to older commits (`mattpocock/skills` 8295b8e10d, `kunchenguid/vision` 7a20c38181, ECC 393d397efa). The run took 30 to 49 seconds, counted 320 changed upstream lines in 14 skills and 11 agents, passed the patch and doctor conditions, and said the pull request would wait. With pins a few days old it counted 0 lines and said it would merge.
- confirmed: during both dry runs every file under `~/.agents/skills` and `~/.claude/agents` kept its checksum, and the lists of `~/.claude/skills` and `~/.claude/backup` did not change. The sync commands ran with `HOME` set to a throwaway folder whose `config.toml` names a throwaway clone as the kit.
- confirmed: `git fetch --depth 1 <repo> <commit>` gets an older ECC commit from GitHub, so the old and the new agent text can be compared.
- confirmed: the repo `labuzniq/wk` allows squash merges and deletes a branch after its merge (`gh repo view --json squashMergeAllowed,deleteBranchOnMerge`).
- docs: `gh pr revert`, `gh pr merge --squash --delete-branch`, `gh pr create --base --head --title --body-file` and `gh pr list --state all --limit --json url,state,headRefName` exist in gh 2.88.1 (read in `--help`).
- docs: `orca automations create --trigger weekly --day 1 --time 08:00 --missed-run-grace-minutes --workspace path:<folder> --fresh-session --enabled` (read in `--help` and in the `orca-cli` skill's automations reference).
- open: no real pull request was pushed, opened or merged by `wk pins-update`. The tests use a local bare repo as the kit's origin and the stand-in for `gh`. The first real run with a newer upstream commit is the test.
- open: the automation "Pin update" was not created in the real Orca; the installer's call is tested with the stand-in for `orca`. Not known: whether a session started by an automation finds `wk` on its PATH, runs `wk pins-update` without a permission question (the kit allows `Bash(wk *)`), and has git and `gh` logged in for the push and the merge.
- open: whether `--workspace path:<kit>` needs the kit to be a repo in Orca. The installer adds it first when it is missing, as `wk adopt` does for a project.
- confirmed: the sync commands run with only a short list of variables (`PATH`, the locale, `TMPDIR`, `TERM`, the user and shell names, the proxy settings), plus `HOME` and `npm_config_cache` in the throwaway folder. No token and no path to a config file of the real home reaches `npx` or the packages it downloads. The real `npx skills@1.9.0` (from Homebrew) installed all 28 skills that way in the dry run.
- open: an `npx` that comes from a version manager under the home folder (`mise`, `nvm`) may not start with `HOME` set to a throwaway folder. On this Mac `npx` is `/opt/homebrew/bin/npx`.
- The merge does not wait for the CI (Continuous Integration) check of the pull request: the vision names three conditions, and a pin update changes only `skills.txt`, `agents/agents.toml` and the two lock files. When GitHub refuses the merge, the run says so and the pull request waits.
- `wk doctor` needs a project. The run makes a scratch project in the throwaway home whose manifest skips the checks of one project (`claude_md`, `mise`, `orca_repo`, `orca_files`, `orca_setup_hook`, `vision`, `vision_fresh`, `matt_setup`, `tracker`, `automations`, `vault_page`, `proposals`), so the checks of the install decide: `skills_visible`, `skills`, `agents`, `patches`. A project check added to the doctor later must be added to that list in `libexec/wk-pins-update`; until then every pin update waits and shows the gap.
- "Upstream text" is what the installer puts on disk before any patch of this repo: every file in the folder of a pinned skill, and `agents/<name>.md` of a pinned agent. The old and the new version are installed without patches into two throwaway homes and compared with `git diff --no-index --numstat`. A changed binary file has no lines, so it makes the pull request wait.
- The longest line of the skills and agents installed on this Mac has 938 characters. A changed line over 1,000 characters makes the pull request wait, because one counted line could hold a page of text.
- A symbolic link or a file mode change in the upstream text makes the pull request wait: `git diff --numstat` counts neither as a changed line.
- `gh pr merge` gets `--match-head-commit` with the commit the run pushed, so a commit someone else pushes to the branch is not merged with it (docs, `gh pr merge --help`).
- The branch name is a checksum of the new pins and of every patch. A closed pull request stops the same versions from being offered again; after a patch is changed, they are offered again.
- A branch that a run pushed without opening its pull request (for example, `gh` was logged out) is deleted and pushed again by the next run.
- The automation is created once. A marker, `~/.local/state/workspace-kit/pin-update-automation`, keeps the installer from creating it again after the owner removes it. When Orca does not answer, the installer says so and goes on without it.
- git runs with `GIT_TERMINAL_PROMPT=0`, so a source repo that asks for a password fails the run instead of waiting for an answer nobody gives.
