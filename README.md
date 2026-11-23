# wk: workspace kit

One repeatable setup for every project, built around [Orca](https://orca.dev) and Claude Code. You open a project folder and say what you want; setup, the task board and session capture run by themselves.

## What it does

- **Project setup without commands.** On first open, the agent runs `wk adopt`: toolchain (`mise.toml`), worktree setup (`orca.yaml`), tracker config, a knowledge vault and two Orca automations.
- **Orca owns worktrees and tasks.** Every worktree Claude Code creates becomes an Orca workspace card. Cards move to `in-progress`, `in-review` and `completed` from commits and pull request state, after every agent turn.
- **Idea to tickets.** The agent follows [Matt Pocock's skills](https://github.com/mattpocock/skills) (`ask-matt`, `to-spec`, `to-tickets`, `implement`…) itself; tickets are Orca cards, specs live in `docs/specs/`.
- **Review gate.** Eleven review and build-fix agents from [ECC](https://github.com/affaan-m/ECC), pinned to one commit, with skills preloaded.
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

**It changes your Claude Code setup.** It replaces `~/.claude/CLAUDE.md` with a link to [`claude/CLAUDE.md`](claude/CLAUDE.md), merges hooks and permission rules into `~/.claude/settings.json`, installs the skills in [`skills.txt`](skills.txt) and the agents in [`agents/agents.toml`](agents/agents.toml). Both files are backed up to `~/.claude/backup/<timestamp>/` first. Read `claude/CLAUDE.md` and make it yours before installing.

Then do the three manual Orca settings in [`docs/orca-settings.md`](docs/orca-settings.md).

## Commands

| Command | What it does |
|---|---|
| `wk new <name>` | Create a project under the projects folder, with the capsule |
| `wk adopt` | Add the capsule to the repo or folder you are in; keeps existing files |
| `wk doctor` | Print one line per missing piece of the capsule |
| `wk board-sync [--repo]` | Move Orca cards forward from git and pull request state |
| `wk agents-sync` | Install the pinned ECC agents |
| `wk transcript <file>` | Print what was said in a Claude Code transcript |

## Layout

```
install.sh       links everything into place
claude/          global CLAUDE.md, settings fragment, merge rules
hooks/           session-start, stop, session queue, worktree create and remove
bin/wk           the CLI; commands live in libexec/
agents/          which ECC agents, the pinned commit, the lock file
skills/          project-setup, wiki-ingest, wiki-lint
templates/       project capsule, vault skeleton, Orca tracker description
docs/            verified facts and the manual Orca checklist
```

## What a project gets

```
.workspace-kit.toml   manifest: slug, stack, Orca repo id, vault path, skipped checks
mise.toml             tools and tasks: setup, test, lint
orca.yaml             setup script Orca runs in each new worktree
.worktreeinclude      local files Orca copies into new worktrees
docs/agents/          where tickets, triage labels and domain docs live
docs/specs/           specs, one section per ticket
knowledge-base/       the vault: raw/ sources and wiki/ pages
```

## Good to know

- If Orca is not running, Claude Code cannot create worktrees: the kit routes them through Orca on purpose and has no fallback.
- The wiki automation commits changes under `knowledge-base/` onto the branch the primary checkout is on, and does not push.
- Third-party skills and agents are never edited. They are installed from their own repos; this repo holds none of their text.

## License

MIT. See [LICENSE](LICENSE).
