# Rules: check or judgment

Every rule of the global instructions (`claude/CLAUDE.md`) is listed here once.

- **check**: a hook can tell from the tool call alone whether the rule is broken. The hook blocks the call and its message says what to do instead. The rule is not in the prose.
- **judgment**: telling needs something a hook does not get, such as what the owner said, what the text means, or what the agent is about to do next. The rule stays in the prose.

When a rule is added to `claude/CLAUDE.md`, add it here. When a check is added for a rule, move the rule to the first table and remove it from the prose (`VISION.md`, "Checks before prose").

## Checks

These rules were in the prose and are now enforced. The hooks are wired in `claude/settings.fragment.json` as `PreToolUse` hooks (they run before a tool call). They make no network call and no Orca call.

| Rule | Hook | What is blocked | What passes on purpose |
|---|---|---|---|
| Create every worktree through Orca; never run `git worktree add` | `hooks/check-command.sh` | A Bash call that runs `git worktree add`. The message names `orca worktree create`. | A repo under the temp folder (`/tmp`, `/var/folders`), or in a folder the command does not spell out (`cd "$(mktemp -d)"`): a test or a trial there needs a plain git worktree. Text inside quotes, a heredoc or a comment. |
| Never use `.claude/worktrees` | `hooks/worktree-create.sh` (already there), with the check above | Claude Code's own worktree tool and `isolation: worktree` call the `WorktreeCreate` hook, which makes an Orca worktree instead. The only other way to make a worktree is `git worktree add`. | |
| Never force-push main | `hooks/check-command.sh` | `git push` with `--force`, `-f`, `--force-with-lease`, `--force-if-includes` or a `+` refspec, when the target is `main` or `master`, every branch (`--all`, `--mirror`, `--branches`), or no branch is named and the checkout is on `main` or `master`. | A forced push that names another branch. A push without force. |
| Write commit messages as conventional commits | `hooks/check-command.sh` | `git commit` with `-m`, `--message` or `-F <file>` whose first line does not start with `<type>: ` or `<type>(<scope>): `. The message lists the types. | Messages git writes (`Merge`, `Revert`, `fixup!`, `squash!`, `amend!`). |
| `wiki/` is written only by the `wiki-ingest` and `wiki-lint` skills | `hooks/check-wiki-write.sh` | `Write`, `Edit`, `MultiEdit` and `NotebookEdit` on a file under the `wiki/` folder of the project's vault. The message names `raw/inbox/`. | A session that a wiki skill marked in its first step (the `no-capture` file for the session); for a wiki run that was not marked, the message gives the command that marks it. Folders named `wiki` outside a vault. |

What the checks cannot see, so that nobody trusts them for more than they do:

- They read the command, they do not run a shell. A value the command does not spell out (`git commit -m "$message"`, `cd "$folder"`, a message file written in the same command) passes unchecked.
- What an earlier part of the same command changes is not known: `git checkout main && git push --force` passes when the checkout was on another branch before.
- A git call hidden in a script, in `bash -c "..."` or in `eval` is not seen.
- A Bash call of more than about 12,000 characters is not checked, because reading it would take too long; the hook says so.
- The wiki check covers the file tools only. A Bash command that writes into `wiki/` (`echo ... >`, `sed -i`, `mv`) is not seen. Neither is a path that spells the folder `Wiki`, or a vault with a full path when the session runs outside its project.
- A commit made in an editor, or with `-F -`, is not checked. Neither is the message of a squash merge (`gh pr merge --squash --subject ...`).
- The type list is the usual eleven. Another type, such as `release:`, is blocked until it is added to `hooks/check-command.sh`.

On input a hook cannot read, it exits with code 1 and one line that says no rule was checked. Claude Code then lets the tool call go on.

## Judgment

| Rule (section) | Why a hook cannot check it |
|---|---|
| Use simple English; skip fancy terms (Language) | "Simple" is a matter of meaning. A word list would block fair uses and miss the rest. |
| Explain every shortcut in brackets (Language) | A hook cannot tell a shortcut from a name, or whether it was explained earlier in the talk. |
| Write steps in the order a person does them (Language) | Needs to understand the steps. |
| The agent runs the flow; the owner types no slash commands (Lifecycle) | It is about what the agent chooses to do, not about one tool call. |
| Pick the step from `ask-matt`, run it, go on to the next one (Lifecycle) | Which step fits depends on what the owner asked for. |
| Say which skill is running; ask only what the skill asks (Lifecycle) | A hook does not see which skill the agent follows. `PreToolUse` input has no such field. |
| Fix capsule gaps with `project-setup` without asking (Lifecycle) | The gaps themselves are a check already (`wk doctor`, shown at session start). Acting on them is the agent's part. |
| Read `VISION.md` before planning; name the principle (Project guidance) | "Before planning" is not a tool call, and naming a principle is a matter of meaning. |
| Read `GLOSSARY.md` and `docs/adr/` and use their words (Project guidance) | Same. |
| Load the `orca-cli` skill before any worktree, terminal, browser or board operation (Orca) | The hook input does not say which skills are loaded. Tracking it would need saved state per session, and a skill can also be read as a file. |
| A ticket is an issue; a workspace is created when work starts, linked to its issue (Orca) | Whether work "starts now" is not in the command. A check for a missing `--issue` would block fair workspaces, such as a trial with no ticket. |
| The tracker and the board are the only task lists; no TODO lists in files (Orca) | A hook cannot tell a task list from a list. `wiki-lint` looks for task state in the wiki. |
| Keep the card status true (Orca) | `wk board-sync` already moves cards from commits and pull request state after every turn. The table stays for the cases it cannot see. |
| Update the card comment at every checkpoint; read it first and keep the owner's goal (Orca) | What a checkpoint is, what the comment should say and which line is the owner's goal need understanding. |
| Remove a worktree only when the owner asks (Orca) | A hook does not know what the owner asked. Blocking `orca worktree rm` always would also block the times the owner did ask. |
| Default: a branch in an Orca worktree, then a pull request; "on main" means commit to main (Git) | Depends on what the owner said. A block on commits to main would break "on main". |
| Do every GitHub operation with `gh`, every GitLab operation with `glab` (Git) | "A GitHub operation" has no fixed form: `curl`, a web fetch, a connector tool, a script. A hook could catch one form (`curl` to `api.github.com`) but not the rule, and reading a public page without `gh` is fine. |
| Ask before discarding uncommitted work (Git) | Discarding has many forms (`reset --hard`, `checkout --`, `restore`, `clean`, `stash drop`, `rm`, writing over a file), and whether the owner was asked is not in the command. |
| Review gate: proof first, then the review agents; only the agents when a review is asked for and no pull request is opened (Review gate) | Whether the proof shows that the change works, and which agents fit, need understanding. A hook on `gh pr create` could look for an Evidence heading, but not tell whether real proof is under it, and a pull request body written another way would be blocked. |
| Build failure, slow path, cleanup: which agent to call (Review gate) | A choice, not a tool call to block. |
| Each project has its own vault; the session-start context names it (Knowledge base) | A fact for the agent, not a rule to enforce. |
| Read the vault's `wiki/index.md` and `wiki/overview.md` before non-trivial work (Knowledge base) | "Non-trivial" is a matter of meaning. |
| "Note this" means a dated note in `raw/inbox/` (Knowledge base) | It tells the agent what the owner's words mean. |
| Session capture is automatic; no closing command (Knowledge base) | It is a fact for the agent, not a rule to enforce. The capture itself is a hook (`hooks/enqueue-session.sh`). |

## Turn a check off

Remove its entry from `hooks.PreToolUse` in `~/.claude/settings.json` and from `claude/settings.fragment.json`, and put the rule's line back into `claude/CLAUDE.md`.
