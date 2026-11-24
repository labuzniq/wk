# Shared vault schema

This vault is the wiki of the tools every project uses: Orca, the agents (Claude Code, Codex), their skills, and the kit (`wk`). It lives outside any repo and is read in every project. `raw/` holds sources; `wiki/` holds what was learned from them.

## Layers
- `raw/` is add-only once committed: add files; the one later edit allowed is `wiki-lint` rewording a private detail. `raw/sessions/` one extract per agent session that taught a tool lesson, `raw/inbox/` one extract per note that did, `raw/sources/` articles and docs. `wiki-ingest` writes these files from a project; nothing is dropped here by hand.
- `wiki/` is written only by the `wiki-ingest` and `wiki-lint` skills. `overview.md` is the page of the tools, `learnings.md` the gotchas and lessons, `concepts/`, `entities/` (tools and systems), `howto/`.
- `wiki/corrections/` holds one record per correction about a tool, `<key>.md`. Its `projects` list holds one id per project it was seen in, written only by `wk kit-correction add`; at three projects the fix is offered to the kit.
- `index.md` lists every wiki page, one line each, by category. `log.md` is append-only: `## [YYYY-MM-DD] ingest|lint | <title>`.

## Page rules
- Frontmatter on every wiki page: `type`, `updated`, `sources`.
- Every claim links to a file in this vault's `raw/`.
- Link pages with `[[wikilinks]]`. Every new page gets an `index.md` line and a `log.md` entry.
- A new source updates existing pages first; create a page only when nothing fits. Mark a contradiction on the page, with both sources.

## Anonymous by rule
Every file here, `raw/` included, is written so that it holds for any project: "a project", "a TypeScript repo", `~/.claude/…` for a path.
- A **private detail** is a project's name or slug, a path in the home folder written out in full, a repo or remote address, a customer, a person, or a piece of a project's code or data.
- `wk shared-vault check` prints one line per project name and home path it finds, and every commit here runs it: a commit with such a line fails. It knows a project by its capsule or its session queue; the other private details are yours to keep out.
- A lesson that cannot be told without a private detail is a project lesson; it belongs in that project's vault. So does a lesson about a tool that has the same name as a project, until the owner adds that name to `.allowed-words`.

## What stays out
- Task state lives on the Orca board. The wiki holds knowledge only: a TODO, backlog, status line or "next steps" belongs on a card.
- What is true of one project lives in that project's vault.
