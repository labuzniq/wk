---
name: project-setup
description: Fix the project capsule gaps that the session-start context lists (missing manifest, CLAUDE.md, mise.toml, Orca files, tracker config, vault, vision, pending proposals). Use when the session context lists capsule gaps or says a folder has no capsule, or when the user asks to set up or adopt a project.
---

The **doctor** is `wk doctor`: it prints one line per **gap**, as `<check_id>: <what is missing; how to fix it>`. Setup is the agent's job: the user opens the folder and talks about their work.

1. Run `wk doctor`. Completion: you hold the full list of gaps.
2. A main checkout with no capsule: do only what the session-start text says (in an existing repo that is `wk adopt-pr`, never `wk adopt`). Otherwise fix each gap that does not say "needs the user", in order, the way its line says. `wk adopt` creates every missing capsule file and keeps existing ones. Infer what you need from the repo. A `correction-<key>` gap is fixed the way [correction-check.md](correction-check.md) says. A `kit-correction-<key>` gap is fixed the way [kit-correction.md](kit-correction.md) says.
3. Commit what changed, following the Git rules.
4. Run `wk doctor` again. Completion: only "needs the user" gaps are left.
5. Handle the user's request. When it is done, raise the "needs the user" gaps, one at a time:
   - `vision`, `vision_fresh`: offer to run the `vision` skill with them now.
   - `correction-<key>`: show the record. On "yes", make the design change in a commit of its own whose message ends with the line `Correction: <key>`. On "no", handle it as "skip".
   - `proposals`: show the proposal file. On "apply", load `writing-for-agents`, make the edit the proposal names, delete the proposal file. On "reject", delete the proposal file.
   - The user answers "skip" to any gap: add `<check_id> = "<their reason>"` under `[skip]` in `.workspace-kit.toml`.
