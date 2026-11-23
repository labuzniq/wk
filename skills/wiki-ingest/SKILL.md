---
name: wiki-ingest
description: Turn queued agent sessions and new raw notes into the project's wiki. Use when asked to run wiki-ingest, or to ingest sessions, inbox notes or sources into the vault.
---

Run from the project's primary checkout. The **vault** is the folder named by `vault` in `.workspace-kit.toml`; its `CLAUDE.md` is the schema and binds every wiki edit. The **queue** is `~/.local/state/workspace-kit/sessions/<slug>/queue/`, one JSON file per session.

1. Mark this session as not to be captured: `mkdir -p ~/.local/state/workspace-kit/sessions/no-capture && touch ~/.local/state/workspace-kit/sessions/no-capture/${CLAUDE_SESSION_ID}`.
2. Read the vault's `CLAUDE.md`, `index.md` and the last ingest entry in `log.md`.
3. If Wispr Flow note tools are available, copy each note newer than that last ingest entry that names this project into `raw/inbox/<date>-<title>.md`.
4. For every file in the queue, oldest first:
   1. Run `wk transcript <transcript_path>`. With `user_turns` under 3, move the queue file to `../skipped/` and take the next one.
   2. Write `raw/sessions/<date>-<slug>-<first 8 characters of session_id>.md`: what was asked, what was decided and why, what was learned, where the user corrected the agent, open questions.
   3. Update the wiki from that summary: existing pages first, usually `wiki/learnings.md` and `wiki/overview.md`, then concept, entity or how-to pages.
   4. Follow-up work found in the session goes on its Orca card, never into the wiki: read the card with `orca worktree show --worktree id:<orca_worktree_id> --json`, then set the same comment with the item added to its `follow-ups:` line.
   5. Where the user corrected the agent, or the same mistake shows in two session summaries, write `wiki/_proposals/<date>-<topic>.md`: the evidence, and the exact edit to a `CLAUDE.md`, to the kit's `agents/agents.toml`, or to a kit skill (`project-setup`, `wiki-ingest`, `wiki-lint`). Third-party skills are out of bounds for proposals.
   6. Move the queue file to `../processed/`.
5. Ingest every file in `raw/inbox/` and `raw/sources/` that git shows as new or changed, the same way as step 4.3.
6. Add an `index.md` line for each new page and one `log.md` entry per ingested item.
7. Commit the vault alone: `git -C <vault> add -A . && git -C <vault> commit -m "docs(wiki): ingest <date>"`.

Done when the queue folder is empty, `git -C <vault> status --porcelain -- .` prints nothing, and no wiki page holds task state.
