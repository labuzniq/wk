# A correction seen in three projects lands in the kit

`wk doctor` prints `kit-correction-<key>` when the same correction was made in three projects. The gap line names the **shared record** in the shared vault: the correction as one rule, its `layer`, and the sources it was seen in. The fix goes to the kit's own repo, once for every project, as one commit offered as a pull request. It is a check where code can catch the mistake (a hook, a `wk doctor` line, a test of the kit), and otherwise a line in the kit's `claude/CLAUDE.md` or a step in a kit skill.

1. Read the shared record and the sources it lists. Completion: you can name the mistake as one concrete thing, such as a command, a pattern in a file or a missing file.
2. Run `wk kit-correction start <key>`. It clones the kit into a fresh folder on the branch `correction/<key>` and prints the folder; do steps 3 to 6 there. The installed kit stays as it is.
3. Write the fix the way steps 2 to 4 of [correction-check.md](correction-check.md) say, in the kit instead of the project: the check where the kit runs its checks, shown red on the old mistake and green without it, and the rule it enforces deleted from `claude/CLAUDE.md`. Completion: `test/run` passes in the clone.
4. A fix for a third-party skill or agent (one pinned in `skills.txt` or `agents/agents.toml`) is a **recorded patch**, `patches/skills/<name>.patch` or `patches/agents/<name>.patch`, in the format "Good to know" in the kit's `README.md` describes. Show it applies: `patch -p1 --dry-run -d ~/.agents/skills/<name> -i <patch>` (for an agent, `-d ~/.claude/agents/ecc`). The kit holds no copy of their text; `offer` refuses a commit with one.
5. Commit the fix as one commit, staging its files by name. The message body holds the red output, and its last line is `Correction: <key>`.
6. Run `wk kit-correction offer <key>` in the clone. It checks the one commit, pushes it, opens the pull request against the kit and prints one line with the way to undo it. When it refuses, fix what its message names and run it again.
7. Tell the user that line, word for word.

When the record's layer is `prose`, or no check you can think of goes red on the mistake: the fix is one line in the kit's `claude/CLAUDE.md` or one step in a kit skill (load `writing-for-agents` first), and steps 5 to 7 stay the same. The commit, the record and the pull request are public to whoever sees the kit: word them for any project; `offer` refuses a project's name or a home path.

Done when `wk kit-correction` prints `offered` for the key. Closing the pull request is the user's "no"; the correction is not offered again.
