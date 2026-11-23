# Vault schema

This vault is the wiki of one project. `raw/` holds sources; `wiki/` holds what was learned from them.

## Layers
- `raw/` is add-only: add files, never edit them. `raw/inbox/` quick notes, `raw/sessions/` one summary per ingested agent session, `raw/sources/` articles, PDFs, exported notes.
- `wiki/` is written only by the `wiki-ingest` and `wiki-lint` skills. `overview.md` is the project page, `learnings.md` the gotchas and lessons, `concepts/`, `entities/` (people and systems), `howto/`.
- `wiki/_proposals/` holds proposed edits to agent instructions, waiting for the user's yes or no.
- `index.md` lists every wiki page, one line each, by category. `log.md` is append-only: `## [YYYY-MM-DD] ingest|lint | <title>`.

## Page rules
- Frontmatter on every wiki page: `type`, `updated`, `sources`.
- Every claim links to a file in `raw/` or to a repo path.
- Link pages with `[[wikilinks]]`. Every new page gets an `index.md` line and a `log.md` entry.
- A new source updates existing pages first; create a page only when nothing fits. Mark a contradiction on the page, with both sources.

## What stays out
- Task state lives on the Orca board. The wiki holds knowledge only: a TODO, backlog, status line or "next steps" belongs on a card.
- Project decisions live in the repo's `docs/adr/`. Link to an ADR (Architecture Decision Record); the wiki holds what crosses decisions or would otherwise be lost: learnings, gotchas, concepts, how-tos, people and systems.
