# wk: workspace kit

One repeatable setup for every project, built around [Orca](https://orca.dev) and Claude Code. You open a project folder and say what you want; setup, the task board and session capture run by themselves.

## What it does

- **Project setup without commands.** On first open of a new folder, the agent runs `wk adopt`: toolchain (`mise.toml`), worktree setup (`orca.yaml`), tracker config, a knowledge vault and three Orca automations. An existing repo on GitHub gets the same capsule as a pull request (`wk adopt-pr`): merge it for yes, close it for no. Nothing lands on its default branch before you merge, and a closed pull request is never offered again.
- **Orca owns worktrees and tasks.** Every worktree Claude Code creates becomes an Orca workspace card. Cards move to `in-progress`, `in-review` and `completed` from commits and pull request state, after every agent turn.
- **Idea to tickets.** The agent follows [Matt Pocock's skills](https://github.com/mattpocock/skills) (`ask-matt`, `to-spec`, `to-tickets`, `implement`…) itself; tickets are issues in the project's tracker (GitHub, GitLab or local files), specs live in `docs/specs/`, and a workspace is created when work on a ticket starts.
- **Review gate.** Before a pull request the agent first gathers proof that the change works (test output, a run of the app, a screenshot) and puts it in the pull request; then the review agents run. Eleven review and build-fix agents from [ECC](https://github.com/affaan-m/ECC), pinned to one commit, with skills preloaded.
- **Session capture.** Finished sessions are queued and turned into a per-project wiki (the [LLM wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)) by a daily Orca automation.

## Requirements

macOS, [Orca](https://orca.dev) with its CLI registered, Claude Code, and on `PATH`: `git`, `jq`, `gh`, `uv`, `npx`, `mise`.

## Install

```bash
git clone https://github.com/labuzniq/wk ~/.workspace-kit
```

```bash
~/.workspace-kit/install.sh ~/code
```

The argument is the folder your projects live in. The installer can be run again at any time; a second run changes nothing.

**It changes your Claude Code setup.** It adds one line to `~/.claude/CLAUDE.md` that imports the shared instructions in [`claude/CLAUDE.md`](claude/CLAUDE.md), merges hooks and permission rules into `~/.claude/settings.json`, installs the skills in [`skills.txt`](skills.txt) at their pinned commits and the agents in [`agents/agents.toml`](agents/agents.toml). Both files are backed up to `~/.claude/backup/<timestamp>/` before they change.

`~/.claude/CLAUDE.md` stays yours: the installer keeps your text and never replaces the file, so your own rules (language, tone, habits) go there, below the import line. The shared rules (Orca, Git, the review gate) stay in the kit and reach everyone with `git pull`. An install from before this split (a link to `claude/CLAUDE.md`) moves to the new layout on the next installer run. Run the installer right after the `git pull` that brings the split: until then the lines that became personal (the Language section) are not loaded, and `wk doctor` reports an `instructions` gap.

Then do the three manual Orca settings in [`docs/orca-settings.md`](docs/orca-settings.md).

## Commands

| Command | What it does |
|---|---|
| `wk new <name>` | Create a project under the projects folder, with the capsule |
| `wk adopt` | Add the capsule to the repo or folder you are in; keeps existing files |
| `wk adopt-pr` | Offer the capsule to an existing repo as a pull request, on a branch in an Orca worktree |
| `wk doctor` | Print one line per missing piece of the capsule |
| `wk board-sync [--repo]` | Move Orca cards forward from git and pull request state |
| `wk worktree-cleanup [--dry-run]` | Remove this project's worktrees whose branch is merged and whose card has been completed for 14 days; print each worktree and why it was removed or kept |
| `wk agents-sync` | Install the pinned ECC agents, with their recorded patches |
| `wk skills-sync` | Install the pinned third-party skills, with their recorded patches |
| `wk transcript <file>` | Print what was said in a Claude Code transcript |

## Checking the kit

```bash
test/run
```

One command runs shell lint (`shellcheck`), Python lint (`ruff`) and the tests (`bats`). On top of the kit's own requirements it needs `shellcheck` and `bats` (`brew install shellcheck bats-core`). The tests run in a throwaway home folder with stand-ins for `orca` and `gh`, so they touch neither your Orca board nor GitHub. CI (Continuous Integration) runs the same command on every pull request.

## Layout

```
install.sh       links everything into place
claude/          global CLAUDE.md, settings fragment, merge rules
hooks/           session-start, stop, session queue, worktree create and remove
bin/wk           the CLI; commands live in libexec/
agents/          which ECC agents, the pinned commit, the lock file
skills.txt       which third-party skills and their pinned commits; skills.lock is the lock file
patches/         recorded patches for third-party skills and agents
skills/          project-setup, wiki-ingest, wiki-lint
templates/       project capsule, starter checks, vault skeleton, Orca workspace rules for the tracker doc
test/            `test/run`, the tests, and stand-ins for orca and gh
docs/            verified facts and the manual Orca checklist
```

## What a project gets

```
.workspace-kit.toml   manifest: slug, stack, vault path, skipped checks
mise.toml             tools and tasks: setup, test, lint
checks/               starter checks for the stack, run by the lint task; the project's own checks go beside them
orca.yaml             setup script Orca runs in each new worktree
.worktreeinclude      local files Orca copies into new worktrees
docs/agents/          where tickets, triage labels and domain docs live
docs/specs/           specs, one section per ticket
knowledge-base/       the vault: raw/ sources and wiki/ pages
```

## Sharing a project

Everything the capsule commits works for everyone who clones the repo. What is true for one person only stays on their Mac: the Orca repo id in `~/.local/state/workspace-kit/repos/`, the vault permission in the gitignored `.claude/settings.local.json`, and the two wiki automations in their own Orca. A second person installs the kit, clones the repo and opens it: the first session reports the `orca_repo` and `automations` gaps, and the agent fixes both with `wk adopt`, which changes no committed file.

## Good to know

- Starter checks: `wk adopt` writes a small lint set per stack into `checks/starter/` (ruff for Python, Biome for TypeScript, SwiftLint for Swift) and adds one command per stack to the lint task. It catches the first mistakes a coding agent makes: swallowed errors, `any` and `@ts-ignore`, debug prints, force unwraps, skipped tests, switched-off checks. When a check fails, the lint task prints what the real problem is and how to fix it. The project's own linter config is not touched. In a `mise.toml` that was already there, `wk adopt` prints the command and `wk doctor` reports `starter_checks` until the lint task runs it.
- If Orca is not running, Claude Code cannot create worktrees: the kit routes them through Orca on purpose and has no fallback.
- A worktree is removed without asking only by the daily `Worktree cleanup: <project>` automation: its branch must be merged, its card completed for 14 days, and it must hold no uncommitted or untracked files. The branch stays. The 14 days count from the first run that saw the card completed, so a run with `--dry-run` also notes that time. One exception: a worktree Claude Code made for a subagent is removed with its branch when the subagent ends and left nothing in it.
- The wiki automation commits changes under `knowledge-base/` onto the branch the primary checkout is on, and does not push.
- Third-party skills and agents are installed from their own repos, each pinned to one commit: skills in `skills.txt` (`owner/repo#<commit>`), agents in `agents/agents.toml`. This repo holds none of their text.
- When a skill or an agent does not fit this setup, it carries a recorded patch: `patches/skills/<name>.patch` or `patches/agents/<name>.patch`, a unified diff with `a/` and `b/` path prefixes (for a skill, paths inside its folder; for an agent, `<name>.md`). `wk skills-sync` and `wk agents-sync` apply it after install. `skills.lock` and `agents/agents.lock` record the checksum before and after, and `wk doctor` reports an install that differs. A patch that no longer applies stops the sync and names the skill or agent. A skill you edited by hand is moved to `~/.claude/backup/` before the pinned one replaces it.

## License

MIT. See [LICENSE](LICENSE).
