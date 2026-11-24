# Correction records

A **correction** is something the user had to tell the agent to do differently. Its **record** is `wiki/corrections/<key>.md` in the vault: one file per correction, listing every session summary the correction was seen in. `wk corrections` counts those sessions; at three the correction is **due** and becomes a check. You judge whether two corrections are the same one; the command does the counting.

For each correction in the session summary you just wrote:

1. Read the title line of every record in `wiki/corrections/`. When one names the same mistake, whatever the words, add this summary to its `sources` and its evidence list, and set `updated`. Otherwise write a new record in this form (create the folder when the vault has none), where `<key>` is the rule in a few lowercase words joined by dashes:

   ```
   ---
   type: correction
   updated: <date>
   layer: <design, check, proof or prose>
   sources:
     - raw/sessions/<summary file>.md
   ---
   # <the correction as one rule>

   - [[raw/sessions/<summary file>]]: what the agent did, and what the user said.
   ```

   `layer` names the cheapest layer that would have prevented the mistake. Take the first that fits:
   - `design`: a change to the project's structure makes the mistake hard to write.
   - `check`: a lint rule, a test, a hook or a `wk doctor` line catches it.
   - `proof`: running the change before calling it done shows it.
   - `prose`: only a line of instructions can say it.

2. Run `wk corrections`. Each line is `<state> <key> <sessions> <layer> <note>`. Repair a `broken` record the way its note says and run the command again.
3. Act on the state of each record you touched:
   - `waiting` (fewer than three sessions): keep one proposal for the key, `wiki/_proposals/<date>-<key>.md`, holding the evidence and the exact edit to a `CLAUDE.md`, to the kit's `agents/agents.toml`, or to a kit skill (`project-setup`, `wiki-ingest`, `wiki-lint`). When the key already has a proposal, add the new evidence to it. Third-party skills are out of bounds for proposals.
   - `due` or `done`: delete the proposal for the key. Your work on it ends here: `wk doctor` shows a due correction to the next session, which writes the check in the project.
