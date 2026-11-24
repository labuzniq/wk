# A due correction becomes a check

`wk doctor` prints `correction-<key>` when the user has made the same correction in three sessions. The gap line names the **record**: the correction as one rule, its `layer`, and the session summaries it was seen in. The fix is a **check**: code that goes red on the mistake, namely a lint rule, a test, a hook or a `wk doctor` line. A line in the project's `CLAUDE.md` is the fix only when no check can express the correction.

1. Read the record and the session summaries it lists. Completion: you can name the mistake as one concrete thing in the repo, such as a command, a pattern in a file or a missing file.
2. Write the check where the project already runs its checks (the lint or test task in `mise.toml`, a hook, the test folder). Its message says what the real problem is and how to fix it, so the next agent that fails it needs nothing else.
3. Show it red: put the old mistake into the working tree, run the check, and keep the output. Take the mistake out and run the check again. Completion: one output that fails with your message, one that passes. A check that stays green on the mistake does not express the correction: write a different one.
4. Delete from the project's `CLAUDE.md` every rule the check now enforces.
5. Commit the check and that deletion alone, staging those files by name. When the Git rules ask for a pull request, the commit gets a branch of its own, so a squash merge keeps it whole. The message body holds the red output from step 3, and its last line is `Correction: <key>`; that line is how `wk doctor` knows the correction is handled, also after a revert.
6. Tell the user in one line what the check catches and how to undo it: `git revert <commit>` (for a pull request: close it, or after the merge revert the merged commit).

When the record's layer is `prose`, or step 3 fails for every check you can think of: add one line to the project's `CLAUDE.md` instead, and do steps 5 and 6 with it.
When the gap line says "corrected again", a check exists and missed the mistake: read the newest session summary in the record, then do steps 2 to 6 on the existing check.

Done when `wk corrections` prints `done` for the key.
