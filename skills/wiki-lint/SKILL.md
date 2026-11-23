---
name: wiki-lint
description: Check the project's wiki against its schema and repair it. Use when asked to run wiki-lint or to lint, check or clean up the vault.
---

Run from the project's primary checkout. The **vault** is the folder named by `vault` in `.workspace-kit.toml`; its `CLAUDE.md` is the schema.

1. Mark this session as not to be captured: `mkdir -p ~/.local/state/workspace-kit/sessions/no-capture && touch ~/.local/state/workspace-kit/sessions/no-capture/${CLAUDE_SESSION_ID}`.
2. Read the vault's `CLAUDE.md`, then every page under `wiki/` except `_proposals/`.
3. Check every page for each of these:
   - **contradiction**: two pages claim opposite things.
   - **superseded**: a claim that a newer file in `raw/` overturns.
   - **orphan**: a page no other page and no `index.md` line links to.
   - **unindexed**: a page without an `index.md` line.
   - **task state**: a TODO, backlog, status line or "next steps".
   - **restated ADR**: a decision copied from `docs/adr/` where a link belongs.
   - **unsourced**: a claim with no link to `raw/` or a repo path.
4. Fix the mechanical findings: add index lines, link orphans, replace a restated ADR (Architecture Decision Record) with a link, move task state to the Orca card it belongs to (or delete it when no card fits).
5. List the judgement calls (contradiction, superseded, unsourced) at the top of `log.md` under `## [<date>] lint | <n> findings`, one line each with the page and the two sources.
6. Commit the vault alone: `git -C <vault> add -A . && git -C <vault> commit -m "docs(wiki): lint <date>"`.

Done when every page was checked against all seven items and `git -C <vault> status --porcelain -- .` prints nothing.
