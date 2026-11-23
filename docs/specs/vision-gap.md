# Vision gap

The work that takes `wk` from what it does today to what the Vision section of `STRATEGY.md` says (that file arrives with the vision pull request).
One section per ticket. Each ticket is one Orca card with the same name.

Order: `kit-test-harness` and `proof-first-review` can start at once. Every other ticket waits for `kit-test-harness`, because the vision says an automation is built only on top of a step that already works without hand correction, and the kit holds its own scripts to that first.

## kit-test-harness

**What to build:** The kit checks itself. A contributor runs one command and learns whether the kit's scripts still work; the same command runs in CI (Continuous Integration) on every pull request.

**Acceptance criteria**

- One command runs every check, and a failing check names the real problem and how to fix it.
- Shell scripts pass shell lint; Python scripts pass lint.
- Tests cover the board status rules, the doctor's gap lines and the session queue hook, with a stand-in for Orca and for `gh`.
- `wk adopt` and `wk doctor` run against a scratch project: the first run creates the capsule, a second run changes nothing, and the doctor prints no fixable gap.
- CI runs the same command on every pull request.

**Blocked by:** None (can start immediately).

## proof-first-review

**What to build:** Before a pull request is opened, the agent first gathers proof that the change works (test output, a run of the app, a screenshot) and puts it in the pull request. The pinned review agents always run after that, for what tests cannot cover and what needs judgment.

**Acceptance criteria**

- The review gate in the global instructions names proof as its first step and says what counts as proof per kind of change.
- A pull request opened by the agent has a proof section, or says plainly why no proof was possible.
- The review agents still run on every pull request.

**Blocked by:** None (can start immediately).

## adopt-by-pr

**What to build:** In an existing repo with history and no capsule, the agent no longer asks. It adds the capsule on a branch in an Orca worktree, opens a pull request and says so in one line. Closing that pull request is the remembered "no".

**Acceptance criteria**

- Nothing is committed to the repo's default branch without a merge by the owner.
- A closed, unmerged capsule pull request means the repo is never offered the capsule again.
- Steps that a closed pull request cannot undo (the Orca automations) happen only after the merge.
- A new folder or empty repo is still set up at once, as today.
- A "no" remembered before this change is still honoured.
- A repo with no GitHub remote cannot get a pull request; there the agent asks once, as today.

**Blocked by:** `kit-test-harness`

## recorded-patches

**What to build:** A third-party skill or agent can carry a small patch when its text does not fit this setup. The patch is a file in this repo; it is applied after install, and the lock file records the result. The upstream text is never copied into this repo.

**Acceptance criteria**

- Third-party skills get a pin and a lock entry like the agents have today; this is part of the work.
- A patch file for one agent and one skill is applied on install and on a second run changes nothing.
- The lock file records the checksum before and after the patch, and the doctor reports a difference.
- A patch that no longer applies fails loudly and names the skill or agent and the patch.
- The README no longer says third-party skills and agents are never edited; it says how patches work.

**Blocked by:** `kit-test-harness`

## pin-update-automation

**What to build:** A scheduled Orca automation offers newer versions of the pinned agents and skills as a pull request. It merges the pull request itself when `wk doctor` passes, every patch still applies and the upstream change is under 50 lines. A bigger change waits for the owner.

**Acceptance criteria**

- The pull request shows what changed upstream, in a form the owner can read.
- The three merge conditions are checked by code, not by the agent's judgment; "under 50 lines" counts added plus removed lines in the upstream text of the pinned skills and agents.
- A self-merge is reported in one line with the way to revert it.
- No new version: no pull request.

**Blocked by:** `kit-test-harness`, `recorded-patches`

## worktree-cleanup

**What to build:** A scheduled Orca automation removes a worktree when its branch is merged and its card has been completed for 14 days. The branch and the card stay.

**Acceptance criteria**

- A worktree that is not merged, or completed for less than 14 days, is never removed.
- A worktree with uncommitted or untracked files is kept and reported.
- Each run prints what it removed and what it kept, and why.
- The global instructions no longer say a worktree is removed only when the owner asks; they state this rule.
- Today's removal hook deletes a clean agent-made worktree and its branch at once; it is brought under this rule, or written down as the one exception, as the owner decides.

**Blocked by:** `kit-test-harness`

## cards-to-issues

**What to build:** Each Orca card of a project has one GitHub issue that mirrors its name, status and comment, so tasks can be read away from the Mac, by colleagues too, and survive a lost laptop. The board stays the source of truth.

**Acceptance criteria**

- A new card gets an issue; a changed card updates its issue; a completed card closes it.
- The mirror is off for a repo without a GitHub remote and can be turned off per project.
- No network call is added to a hook that runs in every session.
- A failed GitHub call never blocks or changes the board.

**Blocked by:** `kit-test-harness`

## issues-to-cards

**What to build:** When someone closes a mirrored issue or comments on it, the change reaches the card: the card completes, or the comment is added to the card.

**Acceptance criteria**

- Closing a mirrored issue completes its card on the next sync.
- A comment on a mirrored issue appears on the card once, with its author.
- A completed card is never moved back by an issue being reopened.
- When card and issue changed at the same time, the card wins and the issue is brought back in line.

**Blocked by:** `kit-test-harness`, `cards-to-issues`

## shared-vault

**What to build:** Lessons that hold across projects (about Orca, the agents and the kit itself) live in one shared vault outside any repo. Orca automations sort lessons between the project vault and the shared vault and keep both in order. Every session can read both.

**Acceptance criteria**

- The installer creates the shared vault once and keeps an existing one.
- Wiki ingest puts a lesson about a tool in the shared vault and a lesson about the project in the project vault, with its source.
- Nothing that names a project's private details reaches the shared vault.
- Session start names both vault paths, and the owner runs nothing by hand.
- The shared vault is linted on a schedule like a project vault; its automations commit inside the vault only and do not push.

**Blocked by:** `kit-test-harness`

## corrections-to-checks

**What to build:** When the owner has made the same correction in three sessions of a project, it becomes a check (a lint rule, a test, a hook or a doctor line), committed on its own, with a one-line report that names how to revert it. It becomes a line in the project's instructions only when no check can express it.

**Acceptance criteria**

- Wiki ingest counts repeated corrections across session summaries and names the cheapest layer that would have prevented each one: project design, check, proof, prose.
- At three, the agent writes the check, shows it failing on the old mistake, and commits it alone.
- The check's message says what the real problem is and how to fix it.
- A rule that the new check enforces is removed from the instructions in the same commit.
- Fewer than three: a proposal waits for the owner, as today.

**Blocked by:** `kit-test-harness`

## corrections-reach-kit

**What to build:** When the same correction shows up in three projects, the check or the instruction line lands in this repo instead of in each project, the same way: one commit of its own, offered as a pull request, with a one-line report that names how to revert it.

**Acceptance criteria**

- Repeated corrections are counted across projects through the shared vault.
- At three projects, the fix is offered to the kit as a pull request against this repo.
- A fix for a third-party skill is a recorded patch, never an edit of its text.

**Blocked by:** `kit-test-harness`, `shared-vault`, `corrections-to-checks`

## rules-into-hooks

**What to build:** Every rule in the global instructions that a hook can check moves into a hook with a clear message, and leaves the prose. The global instructions hold only what needs judgment.

**Acceptance criteria**

- Each rule in the global instructions is listed as "check" or "judgment", with the reason.
- Each "check" rule is enforced by a hook whose message says what to do instead.
- The enforced rules are gone from the prose.
- Hooks that run in every session stay fast: no network calls and no waiting on Orca.

**Blocked by:** `kit-test-harness`

## starter-checks

**What to build:** `wk adopt` gives a project a starter set of checks for its stack (TypeScript, Python, Swift), so the agent's first mistakes are caught from day one. Each check's message names the root cause. A project's own corrections add to the set.

**Acceptance criteria**

- A newly adopted project of each stack has the starter checks wired into its lint task.
- An existing lint config is kept; the starter checks are added beside it or skipped with a printed reason.
- Each check has a message that says what the real problem is and how to fix it.
- The run prints which checks it added.
- A project adopted before this change gets a doctor gap line that offers the starter checks.

**Blocked by:** `kit-test-harness`

## opt-in-self-merge

**What to build:** In a project that opts in with a flag in its manifest, the agent merges its own pull request when every check passes, proof is attached and the review agents raise nothing above low. It completes the card and reports in one line. Without the flag, the card waits for the owner as today.

**Acceptance criteria**

- The flag is off by default.
- The three conditions are checked by code, not by the agent's judgment: the review result and the proof are stored in a form a script can read.
- A self-merge report names the pull request and the way to revert it.
- Any failed condition leaves the card in review.

**Blocked by:** `kit-test-harness`, `proof-first-review`

## second-person

**What to build:** A second person can install the kit and work on a repo that carries the capsule. What differs between people is a flag or a personal file outside the repo; what the capsule commits works for everyone who clones it. Every run prints what it changed.

**Acceptance criteria**

- Nothing committed by the capsule holds a value that is true for one person only.
- The global instructions split into a shared part and a personal part that the installer never replaces.
- A second person who clones an adopted repo and opens it gets a working setup with no manual steps.
- An existing install moves to the new layout on the next installer run, with a backup.

**Blocked by:** `kit-test-harness`

## codex-support

**What to build:** A card can be worked by Claude Code or by Codex. Codex gets the same global instructions and skills, the same hooks where Codex has them, and its sessions are captured into the wiki.

**Acceptance criteria**

- Each claim about Codex is tested on a real machine or marked "docs" or "open" in the verified-facts record, with the same result words it uses today.
- The installer sets up Codex only when Codex is installed, and prints what it did.
- A finished Codex session is queued and ingested like a Claude Code session.
- Where Codex lacks a hook the kit relies on, the gap is written down, not worked around silently.

**Blocked by:** `kit-test-harness`, `second-person`
