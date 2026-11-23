---
name: wiki-ingest
description: Turn queued agent sessions and new raw notes into the project's wiki, and their lessons about tools into the shared vault. Use when asked to run wiki-ingest, or to ingest sessions, inbox notes or sources into the vault.
---

Run from the project's primary checkout. The **vault** is the folder named by `vault` in `.workspace-kit.toml`. The **shared vault** is the folder `wk shared-vault path` prints. Each one's `CLAUDE.md` is its schema and binds every edit there. The **queue** is `~/.local/state/workspace-kit/sessions/<slug>/queue/`, one JSON file per session.

A **lesson** is one thing learned. Each lesson has one home, decided by one test: would it read true, word for word, in a project that shares only its tools with this one?

- **tool lesson** (yes): about Orca, an agent (Claude Code, Codex), a skill, or the kit (`wk`, its hooks, its templates). Home: the shared vault.
- **project lesson** (no, or in doubt): home: the vault.

1. Mark this session as not to be captured: `mkdir -p ~/.local/state/workspace-kit/sessions/no-capture && touch ~/.local/state/workspace-kit/sessions/no-capture/${CLAUDE_SESSION_ID}`.
2. Read both schemas, then the vault's `index.md` and the last ingest entry in its `log.md`.
3. If Wispr Flow note tools are available, copy each note newer than that last ingest entry that names this project into `raw/inbox/<date>-<title>.md`.
4. For every file in the queue, oldest first:
   1. Run `wk transcript <transcript_path>`. With `user_turns` under 3, move the queue file to `../skipped/` and take the next one.
   2. Write `raw/sessions/<date>-<slug>-<first 8 characters of session_id>.md`: what was asked, what was decided and why, what was learned, where the user corrected the agent, open questions.
   3. Update the wiki with the project lessons of that summary: existing pages first, usually `wiki/learnings.md` and `wiki/overview.md`, then concept, entity or how-to pages.
   4. When the summary holds tool lessons, write them, and only them, to the shared vault's `raw/sessions/<date>-<first 8 characters of session_id>.md`, worded as that schema's "Anonymous by rule" section asks. Then update the shared vault's wiki from that file, `wiki/learnings.md` first, each claim linked to it. Completion: every tool lesson of the summary is on a shared wiki page with that link, and on no page of the vault.
   5. Follow-up work found in the session goes on its Orca card, never into the wiki: read the card with `orca worktree show --worktree id:<orca_worktree_id> --json`, then set the same comment with the item added to its `follow-ups:` line.
   6. Where the user corrected the agent, or the same mistake shows in two session summaries, write `wiki/_proposals/<date>-<topic>.md`: the evidence, and the exact edit to a `CLAUDE.md`, to the kit's `agents/agents.toml`, or to a kit skill (`project-setup`, `wiki-ingest`, `wiki-lint`). Third-party skills are out of bounds for proposals.
   7. Move the queue file to `../processed/`.
5. Ingest every file in `raw/inbox/` and `raw/sources/` that git shows as new or changed, the same way as steps 4.3 and 4.4. The shared source of its tool lessons is the shared vault's `raw/inbox/<date>-<topic>.md`.
6. In each vault that changed, add an `index.md` line for each new page and one `log.md` entry per ingested item.
7. Commit the vault alone: `git -C <vault> add -A . && git -C <vault> commit -m "docs(wiki): ingest <date>"`.
8. When the shared vault changed, run `wk shared-vault check` and reword every line it prints until it prints nothing. Then commit the shared vault alone, without pushing: `git -C <shared vault> add -A . && git -C <shared vault> commit -m "docs(wiki): ingest <date>"`. That commit runs the same check; when it fails, reword and commit again.

Done when the queue folder is empty, `git status --porcelain -- .` prints nothing in the vault and in the shared vault, and no wiki page holds task state.
