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
| 5.2 implies a new card may be `todo` | New cards start `in-progress` | Ticket creation always sets `todo` right after create. |
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
- The `vision` skill may write the vision into `STRATEGY.md` instead of `VISION.md`; the `vision` check accepts either.
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
