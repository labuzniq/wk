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

## A second person (2026-11-23)

- docs: a `CLAUDE.md` file imports another file with a line `@path/to/file`. Relative and absolute paths are allowed; a relative path is read from the folder of the file that holds the import. A space in the path needs a backslash before it. Imports nest up to four levels, and an `@` inside a code span or a code block is no import. Source: https://code.claude.com/docs/en/memory, "Import additional files".
- docs: imports in the user-level `~/.claude/CLAUDE.md` load without an approval dialog (except in Cowork sessions); the dialog is only for a project file that imports a file outside the project. Same page.
- open: the import in `~/.claude/CLAUDE.md` was not seen working in a real session. A run with a throwaway `CLAUDE_CONFIG_DIR` stops at "Not logged in", and the real `~/.claude` is out of bounds for a ticket. To check after the next installer run: start a session and ask which sections the global instructions hold.
- open (not in the docs): what Claude Code does when the imported file is missing, and where a relative import is read from when `CLAUDE.md` is a link. The kit avoids both: the import is an absolute path, `~/.claude/CLAUDE.md` is a real file, and `wk doctor` has an `instructions` check for the import line.
- confirmed: `orca repo show --repo path:<primary checkout> --json` finds the repo on this Mac, and answers `repo_not_found` for the path of a worktree. The tracker doc now names the repo by `path:`, so no committed file needs the Orca repo id.
- `install.sh`: `~/.claude/CLAUDE.md` is the person's own file with one import line for `claude/CLAUDE.md`. A missing file is written, a file without the line gets it as its first line (backup first, text kept), and a link of the old layout becomes a real file that also holds the Language section the kit used to ship (`claude/personal-before-split.md`). A missing `~/.claude/settings.json` no longer stops the installer.
- `wk adopt` saves the Orca repo id in `~/.local/state/workspace-kit/repos/<checksum of the primary checkout's path>`, and the `orca_repo` check reads that file (no Orca call). This replaces the Phase 5 line "`orca_repo` passes when `orca_repo_id` is set in `.workspace-kit.toml`".
- A capsule from before this change still has `orca_repo_id` in its manifest. The doctor and the hooks ignore the line. Each person gets the `orca_repo` gap once per project, and the agent fixes it with `wk adopt`. In the primary checkout `wk adopt` also removes the line, swaps the two places in `docs/agents/issue-tracker.md` that name the id, and prints both; the `shared_values` check asks for this in the primary checkout only, so a ticket's worktree gets no unrelated change.
- `wk adopt` takes the slug from a manifest that is already there. Before, a clone in a folder of another name got automations and a session queue under the folder's name. Found by the new test.
- confirmed: `test/install.bats` runs a copy of `install.sh` in a throwaway home with stand-ins for `wk`, `orca` and `npx`: a fresh install, a second run, an install of the old layout, and a file the person wrote themselves. The real installer was not run on this Mac.

## Worktree cleanup (2026-11-23)

Orca 1.4.271. Nothing was removed on this Mac for these checks: `orca workspace cleanup run` was not run, and `wk worktree-cleanup` ran only in the tests, against a stand-in for `orca`.

- docs: Orca has its own cleanup (`orca workspace cleanup preview`, `run`, `report`). Its rules "are set in Orca settings; these commands never change them" (`--help`).
- confirmed: no cleanup rule is on here. `preview --json` gives every worktree `evaluation: {action: "keep", cause: "rules-off"}` (main checkouts: `not-removable`), and `report --json` gives `runs: []`, `nextRunAt: null`.
- open: whether an Orca rule can say "branch merged and card completed for 14 days, keep the branch, keep a worktree with uncommitted or untracked files". The CLI (Command Line Interface) does not print the rules or their options, and no file under `~/Library/Application Support/orca/` names them. It needs a look in the Orca settings window. Until then the kit holds the rule itself, in `wk worktree-cleanup`; leave Orca's own rules off so that only one thing removes worktrees.
- confirmed: `orca worktree list --json` gives no time at which a card became completed. A card has `createdAt`, `lastActivityAt` and `workspaceStatus` only. `wk worktree-cleanup` therefore writes down the time it first sees a card completed (`~/.local/state/workspace-kit/completed/`), and counts the 14 days from there. That time is never earlier than the real one, so a worktree is never removed too soon; with a daily run it is one to two days late. It covers a card completed by `wk board-sync`, by the agent or by hand.
- confirmed: a card has an `instanceId` next to its `id`. The `id` is `<repoId>::<path>`, so a new worktree at the same path gets the same `id`; the noted time is filed under `instanceId`. Open: that a new worktree at an old path gets a new `instanceId` was not tested. If it does not, the time is still dropped on the first run that sees the new card not completed.
- confirmed: `orca worktree list --repo path:<primary checkout> --limit <n> --json` lists one project's worktrees, and says `truncated: true` when the limit cut the list.
- confirmed: a failed Orca call with `--json` exits 1 and prints `{"ok": false, "error": {"message": ...}}` on standard output. Seen with `orca worktree rm --worktree current --json`, which Orca always refuses.
- docs: `orca worktree rm` without `--delete-branch` keeps the local branch, and without `--force` forces nothing (`--help`). `wk worktree-cleanup` passes neither flag.
- open: whether the card stays on the board after `orca worktree rm`. The ticket asks for it. Testing it means removing a real worktree, which was not done. There is no `orca worktree archive` command.
- open: whether the precheck of an automation runs with `orca`, `jq`, `gh` and `git` on `PATH`. If it does not, the precheck fails, the run shows as `skipped_precheck` in `orca automations runs`, and nothing is removed. The automation was created only against the stand-in.
- "Merged" is checked as: the worktree's newest commit is reachable from the card's base ref, or `gh pr view <branch>` says `MERGED` with that same commit as its head. A squash merge is therefore seen only through GitHub; a GitLab squash merge is not seen and the worktree stays.
- `git worktree remove`, which Orca calls, deletes ignored files (such as `.env` or `node_modules`) together with the folder. Only uncommitted and untracked files keep a worktree.
- `wk doctor` makes no Orca call, so it cannot ask Orca for the automations. `wk adopt` writes the names of the automations it made sure of into its marker file in `~/.local/state/workspace-kit/automations/` (see the section above), and the doctor's `cleanup_automation` check reads the names. A project adopted before this change shows the gap once; `wk adopt` then creates the automation.

## Starter checks (2026-11-23)

Each config in `templates/checks/starter/` was run on this Mac in a throwaway project: once on a file with every mistake, once on a clean file.

- confirmed: `mise x <tool>@<version> -- <command>` downloads the tool on first use and runs it with no `[tools]` entry; tested with mise 2026.11.12 for `ruff@0.17.6`, `biome@2.6.8` and `swiftlint@0.65.1`. The starter command in the lint task is therefore one line that needs nothing from the project.
- confirmed: `mise run lint` runs each entry of a `run` list through a shell, so `<linter> || { cat <messages>; exit 1; }` prints the messages and fails the task. Tested for all three stacks after a real `wk adopt` in a throwaway HOME.
- confirmed (ruff 0.17.6): `ruff check --config checks/starter/python.toml` uses only that file, also when `pyproject.toml` has its own `[tool.ruff]`. The file may have any name that ends in `.toml`. Paths under `[lint.per-file-ignores]` are relative to the folder ruff runs in. `S110` reports `except ValueError: pass` only with `check-typed-exception = true`. All six rules fired; the clean file passed.
- confirmed (Biome 2.6.8): a file named `biome.json` in a subfolder stops the run with "Found a nested root configuration"; a file with another name, given as `--config-path=checks/starter/ts.json`, works, also beside a `biome.json` at the root. `"recommended": false` prints a deprecation warning; `"preset": "none"` is the current form. With `vcs.useIgnoreFile` the files in `.gitignore` are not checked. All six rules fired; the clean file passed.
- confirmed (SwiftLint 0.65.1): `excluded` paths are relative to the config file, not to the folder SwiftLint runs in. `--strict` makes a finding exit with a code other than 0. With `--config`, a `.swiftlint.yml` at the root is not read. `match_kinds: identifier` keeps the `print` rule quiet in strings and comments. All five rules fired; the clean file passed.
- ruff cannot change the text of a rule's message, and SwiftLint only for its custom rules. So each stack has a messages file that the lint task prints on failure, after the linter's own lines.
- open: the starter command inside an Orca worktree and in a project's CI (Continuous Integration); both need `mise` and network on the first run. Not tested: it needs a real adopted project.
- open: Biome and SwiftLint on a large real project (noise from `noEmptyBlockStatements` on empty functions, speed). Tested on throwaway files only.
- confirmed: a folder is kept out of the starter checks with `extend-exclude` (ruff, path relative to the project root), `"!<folder>"` in `files.includes` (Biome) and `excluded` (SwiftLint). The project's own excludes are not read, because `--config` replaces the project's config. Each messages file says where to add a folder.
- confirmed (SwiftLint 0.65.1): with no Swift file the run fails with "No lintable files found"; `allow_zero_lintable_files: true` makes it pass. ruff and Biome pass with no file.
- confirmed (Biome 2.6.8): `// biome-ignore lint/suspicious/noConsole: <reason>` on the line above switches the rule off for that line.
- The starter command is first in the lint task: mise stops at the first command that fails, and the project's own linter may not be installed yet.
- The tests in `test/` need no network. `test/starter-checks.bats` runs the real ruff from the uv cache (`uvx --offline`; `test/run` fills the cache in its Python lint step) and the real SwiftLint when it is installed; each test is skipped when its tool is missing. Biome is not run by the tests.

## Corrections become checks (2026-11-23)

- confirmed: `git log --all -E --grep` matches each line of a commit message on its own, so `Correction: <key>` is found as the last line of a commit and inside a squashed message. Tested with git 2.48 on this Mac by `test/corrections.bats`.
- confirmed: a squash merge on GitHub keeps the full messages of the squashed commits, not indented (see commits #20 to #22 of this repo), so the `Correction: <key>` line survives a squash merge with the default message. Not tested: a repo set to use only the pull request title as the squash message; there the line is lost and the correction is reported again.
- confirmed: `git revert` writes a new message without the lines of the old one, and the old commit stays in the history, so a reverted check still counts as handled.
- confirmed: `wk corrections` with 3 records, one of them due, takes about 0.08 seconds under stock bash 3.2 (one `awk` per record, and one `git log` for all due records together); the doctor calls it in every session and it makes no network call.
- confirmed: bash 3.2 does not read `$'\n'` inside a here-document, so the script splits lines before the here-document.
- A check counts as missed when a session summary in the record is dated after the day of the check's commit; a correction made again on the same day is not seen until a later session.
- open: no real ingest run has written correction records yet. The record form and the two skill texts are tested only through `wk corrections` and `wk doctor` with hand-made records.

## Opt-in self-merge (2026-11-23)

- confirmed: `gh pr view --json number,url,state,isDraft,isCrossRepository,baseRefName,headRefOid,changedFiles,statusCheckRollup,author,body` answers in one call (gh 2.88.1, read on pull request #22). A GitHub Actions job is one `statusCheckRollup` entry with `__typename` `CheckRun`, `status` `COMPLETED` and `conclusion` `SUCCESS`.
- docs: a commit status (not a check run) is an entry with `__typename` `StatusContext` and a `state` of `SUCCESS`, `PENDING`, `FAILURE`, `ERROR` or `EXPECTED` (GitHub GraphQL reference). Not seen on this repo, which has no such status.
- confirmed: `gh api repos/<owner>/<repo> --jq .default_branch` prints the default branch.
- confirmed: `gh api -H "Accept: application/vnd.github.raw" "repos/<owner>/<repo>/contents/<file>?ref=<branch>"` prints the file as it is on that branch; a file that is not there exits 1 with `HTTP 404`. `wk self-merge` reads the flag this way, so the copy in the worktree and the copy on the pull request's branch do not count.
- confirmed: `gh api --paginate repos/<owner>/<repo>/pulls/<number>/files` lists each changed file as `filename`; docs: a moved file also has `previous_filename`, and the list ends at 3,000 files (GitHub REST reference). The command compares the count with `changedFiles` and refuses when they differ.
- confirmed: `gh api user --jq .login` prints the account `gh` is logged in as.
- docs: `gh pr merge <number> --squash --match-head-commit <sha>` merges only when the pull request's head is still that commit; `gh pr revert <number>` opens a pull request that undoes a merged one (`--help` of gh 2.88.1).
- docs: `orca worktree set --worktree id:<id> --workspace-status completed --comment <text> --json` (`--help`); confirmed: `orca worktree current --json` has `id`, `comment` and `isMainWorktree` under `.result.worktree`.
- open: no real pull request was merged by `wk self-merge`; the merge, the edit of the pull request body and the card update are tested with the stand-ins only, because the ticket forbids a real merge.
- open: with a merge queue, `gh pr merge` may return before the merge. The command then reports "not merged yet" and leaves the card to `wk board-sync`. Not tested for real.
- open: a required check that has not reported yet may be missing from `statusCheckRollup`. GitHub's branch protection then refuses the merge, and the command never passes `--admin`; without branch protection such a check is not seen.
- open: when one check name ran twice on a commit and one run failed, the command counts the failure, even if the later run passed.
- The record lives in the pull request body, not in a file under the kit's state folder: the owner can see it on GitHub, it survives a new session and a new machine, and it sits next to the proof. It names the reviewed commit, so a record copied from another pull request or left over from before a push does not count.

## Rules into hooks (2026-11-23)

Claude Code 2.1.311. The list of rules, and which hook checks which, is in `docs/rules.md`.

- confirmed: a `PreToolUse` hook gets JSON on stdin with `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, `tool_name`, `tool_input` and `tool_use_id`. For `Bash`, `tool_input` holds `command` and `description`; for `Write`, `file_path` (a full path) and `content`. Read from a real session with a hook that saved its input.
- confirmed: a hook that exits with code 2 stops the tool call, and the agent gets the hook's stderr as `PreToolUse:<tool> hook error: [<hook path>]: <stderr>`. Tested in a real session in a throwaway repo: `git commit -m "wip"` and a `Write` under the vault's `wiki/` did not run, and the agent quoted the message word for word; `git commit -m "chore: second"` ran.
- confirmed: the block holds in `bypassPermissions` mode, and against a `permissions.allow` rule that matches the command (`Bash(git *)`, with `git push --force origin main`).
- confirmed: the matcher `Bash` and the matcher `Write|Edit|MultiEdit|NotebookEdit` ran the hooks for `Bash` and `Write` calls.
- docs: `tool_input` of `Edit` holds `file_path`. The docs do not list the fields of `MultiEdit` and `NotebookEdit`; the hook reads `file_path`, then `notebook_path`. A `NotebookEdit` call with another field name passes with the "not checked" line.
- confirmed: a hook that exits with code 1 does not block: in a real session the Bash call ran, and the agent did not see the hook's stderr. docs: the transcript shows it to the owner as a hook error. The hooks use exit 1 with one line on stderr for input they cannot read.
- docs: hooks from the settings files also run inside subagents. Not tried in a real session.
- docs: the hook input has no field that names the skill in use. This is why the wiki check reads the `no-capture` mark the wiki skills set in their first step, and why "load the `orca-cli` skill first" stays a judgment rule.
- confirmed: `${CLAUDE_SESSION_ID}` in a skill loaded with the Skill tool is replaced by the same value as `session_id` in the hook input. The Bash tool also has it as the environment value `CLAUDE_CODE_SESSION_ID`; it has no `CLAUDE_SESSION_ID`. Tested with a stand-in skill in a real session.
- open: when the agent reads a wiki skill's `SKILL.md` as a file, `${CLAUDE_SESSION_ID}` is not replaced, the shell sees an empty value and no mark is made. Nobody has seen this happen with the wiki skills. For that case the wiki check's message gives the exact command that marks the session, so a wiki run is not stuck. The skills are left as they are.
- confirmed: time for one call on this Mac, average of 10: a Bash call without the word `git` 13 ms; a git command 28 ms; a forced push without a branch (one local `git branch --show-current`) 44 ms; a file write outside `wiki/` 24 ms; a file write under a `wiki/` folder 135 ms.
- confirmed: `jq` needs more time with every word: a Bash call of 10,000 characters made only of quoted words took 0.7 seconds, one of 20,000 took 2 seconds. A usual long command (one heredoc of 430,000 characters) took 0.2 seconds. The hook therefore does not check input above 12,000 characters.
- confirmed: `jq` 1.7.1 (the one macOS ships) runs `hooks/check-command.jq`: named groups, back references and lazy matching work in its regular expressions.

## A workspace follows its issue (2026-11-23)

- confirmed: a card with a linked GitHub issue has `linkedIssue: <number>` and `createdAt` (milliseconds since 1970) in `orca worktree current --json`, `orca worktree list --json` and `orca worktree show --json`. A card without one has `linkedIssue: null`. Read on this Mac from the cards of this repo.
- confirmed: `gh pr view <branch> --json state,reviewDecision,body,closingIssuesReferences` lists the issues the merge will close as `closingIssuesReferences[].number`. Read from pull request #22 of this repo, whose body says `Closes #7`.
- confirmed: `gh issue view <number> --json state,comments` gives `state` (`OPEN` or `CLOSED`) and, per comment, `id`, `author.login`, `body` and `createdAt` (such as `2026-03-02T21:43:46Z`). Read from a public repo.
- docs: `gh pr edit <branch> --body <text>` replaces the body (`gh pr edit --help`). `orca worktree set --comment <text>` replaces the whole card comment (`orca worktree set --help`); there is no flag that adds a line.
- open: GitHub documents that a closing word such as `Closes #7` closes the issue only when the pull request goes into the default branch. Not tested here. For a pull request into another branch the line is added once and the issue stays open after the merge.
- open: `wk board-sync` was tested with stand-ins for `gh` and `orca`. No real pull request body was edited and no real card comment was written by it, because the rules of this ticket's work allowed one pull request and no issue comment.
- confirmed: each comment in `gh issue view --json comments` also has `authorAssociation` (`OWNER`, `MEMBER`, `COLLABORATOR`, `NONE` and others). Read from a public repo. Only the text of an owner, member or collaborator is copied to the card, because the card comment is shown to the agent at session start. For anyone else the card gets the author and `(not a member of the project; text not copied)`.
- confirmed: jq 1.7.1 on this Mac refuses a time with parts of a second (`2026-02-01T10:00:00.5Z`) in `fromdateiso8601`. The sync cuts that part off first.
- `wk board-sync` asks GitHub for the issue at most once per 10 minutes per worktree, next to the question about the pull request. It runs in the background after each agent turn; the hooks themselves make no network call.
- The question about the pull request is held back for 10 minutes only after an answer. While a pushed branch has no pull request, each sync asks again, so a pull request opened right after a sync is seen by the next one.
- `Closes #<number>` is added to a pull request once per worktree (marker file `~/.local/state/workspace-kit/gh/<key>.named`). An owner who takes the line out keeps it out.
- A completed card is asked about its issue too, so a comment on a reopened issue still reaches the card. Its status is not touched.
- One copy of `wk board-sync` works on a card at a time (folder `~/.local/state/workspace-kit/gh/<key>.lock`): the session-start hook starts two copies at once. A folder left by a killed copy is taken over after 10 minutes.
- Only a GitHub issue is followed. A card with a GitLab issue (`linkedGitLabIssue`) or with local ticket files has no `linkedIssue`, so nothing is asked.
- `orca worktree set --comment` replaces the whole comment. The sync reads the card comment again right before it writes, but an agent that writes an older copy back after that removes the new line, and the line is not added a second time. The comment stays on the issue.
- A comment written before the workspace was created is not put on the card: the agent reads the issue when it starts work.
- An issue closed for any reason (done, not planned, duplicate) completes the card. A card that the owner moves back by hand while the issue stays closed is completed again on the next sync; reopen the issue to keep it open.

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
- `wk doctor` needs a project. The run makes a scratch project in the throwaway home whose manifest skips the checks of one project and of the person's own `~/.claude/CLAUDE.md` (`claude_md`, `mise`, `orca_repo`, `shared_values`, `orca_files`, `orca_setup_hook`, `starter_checks`, `vision`, `vision_fresh`, `matt_setup`, `tracker`, `automations`, `cleanup_automation`, `vault_page`, `proposals`, `instructions`), so the checks of the install decide: `skills_visible`, `skills`, `agents`, `patches`. A check of that kind added to the doctor later must be added to that list in `libexec/wk-pins-update`; until then every pin update waits and shows the gap.
- "Upstream text" is what the installer puts on disk before any patch of this repo: every file in the folder of a pinned skill, and `agents/<name>.md` of a pinned agent. The old and the new version are installed without patches into two throwaway homes and compared with `git diff --no-index --numstat`. A changed binary file has no lines, so it makes the pull request wait.
- The longest line of the skills and agents installed on this Mac has 938 characters. A changed line over 1,000 characters makes the pull request wait, because one counted line could hold a page of text.
- A symbolic link or a file mode change in the upstream text makes the pull request wait: `git diff --numstat` counts neither as a changed line.
- `gh pr merge` gets `--match-head-commit` with the commit the run pushed, so a commit someone else pushes to the branch is not merged with it (docs, `gh pr merge --help`).
- The branch name is a checksum of the new pins and of every patch. A closed pull request stops the same versions from being offered again; after a patch is changed, they are offered again.
- A branch that a run pushed without opening its pull request (for example, `gh` was logged out) is deleted and pushed again by the next run.
- The automation is created once. A marker, `~/.local/state/workspace-kit/pin-update-automation`, keeps the installer from creating it again after the owner removes it. When Orca does not answer, the installer says so and goes on without it.
- git runs with `GIT_TERMINAL_PROMPT=0`, so a source repo that asks for a password fails the run instead of waiting for an answer nobody gives.

## Shared vault (2026-11-23)

- confirmed: `wk shared-vault` in a throwaway home creates the vault as its own git repo, with one commit, and a second run changes nothing. `install.sh` was run in a throwaway home with stand-ins for `orca` and `npx` (`test/install.bats`); it was not run against the real home.
- confirmed: a `pre-commit` hook in the vault stops a commit when `wk shared-vault check` finds a project's name or a home path. With a global `core.hooksPath`, git would skip the vault's own hook; the kit then sets `core.hooksPath` to `.git/hooks` inside the vault. Tested with a global setting in the throwaway home.
- confirmed: BSD `grep -rniwF` matches a project's name as a whole word, in any letter case. `cp -Rn` on this macOS exits 1 when it skips a file that is there, so its exit code is not used.
- confirmed: `;;&` in a `case` is not in bash 3.2; the stand-ins stay without it.
- docs: `permissions.additionalDirectories` in the user's `~/.claude/settings.json` gives every session access to a folder (check V12 covers the key). **open**: not tried in a real session that the shared vault can be written without a permission question; it needs the real home. A session that was already open when the entry was added does not have it.
- open: the automation `Wiki lint: shared` is created the way `wk adopt` creates a project's (`orca repo add --path`, then `--workspace path:<vault>`), tested only against the stand-in. No real Orca automation was created. Check V10 (do automations fire while Orca is closed) holds for it too.
- open: whether `orca automations edit` can move an automation to another folder. The kit does not try: after a change of `shared_vault` it names the automation to remove.
- The doctor does not ask Orca (hooks stay fast). `wk shared-vault` writes `~/.local/state/workspace-kit/shared-vault-ready` once the automation is there, and the doctor reads that file.
- This replaces the row "0.2: one vault path" in part: the global config now has a `shared_vault` key and the shared vault is in the global `additionalDirectories`. A project's vault is still one per project, inside its repo.
- The check knows a project by its capsule (`.workspace-kit.toml`, up to three levels under the projects folder: its folder name and its slug) and by its session queue folder. A folder that only groups projects is not a name. Customers, people, repo addresses and code are not something the check can see; the skill text and the vault's schema carry that rule.
- open: every project's ingest runs at 07:30 and may write the shared vault in the same minutes. The skill keeps that step short (new source files first, wiki pages and the commit in one go at the end); two runs have not been tried side by side.
- Found on the way: on bash 3.2 a failing `[[ … ]]` in the middle of a bats test does not fail the test. The new tests use `has` and `lacks` from `test/helpers.bash`; the older tests still hold such lines.

## Corrections reach the kit (2026-11-24)

- confirmed: `git clone` of a repo shares its first commit, so a checksum of the first commit and the slug names the same project in every clone and on every Mac, and names no project by itself. Two projects made from one template repo with the same slug would count as one. Tested by `test/kit-correction.bats`.
- confirmed: `wk shared-vault check` prints nothing for a shared record whose projects are listed by that id, with the project names in the projects folder. Tested by `test/kit-correction.bats`.
- confirmed: after `git clone`, `git symbolic-ref --short refs/remotes/origin/HEAD` prints `origin/<default branch>` (git 2.48 on this Mac, with a local bare repo as origin).
- open: no real pull request was opened by `wk kit-correction offer`; the push goes to a local bare repo and `gh pr create` to the stand-in in the tests, because the ticket forbids a real one. The first real offer is the test.
- open: whether `gh pr create`, run in the clone, picks the kit's repo on GitHub without `--repo`. It does for `wk pins-update`, which also runs in a clone of the kit; not tested for this command.
- open: no real ingest has written a shared record yet; the record form and the skill texts are tested only through `wk kit-correction` and `wk doctor` with hand-made records.
