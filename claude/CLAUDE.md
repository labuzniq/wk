# Global instructions

## Language
- Use simple English. Skip fancy terms such as "converge" or "amend".
- Explain every shortcut by adding its meaning in brackets, e.g. PII (Personally Identifiable Information).
- Write things that need doing like an aircraft manual: ordered the way a person would really do them.

## Lifecycle
- I open a project and say what I want. You run the flow; I type no slash commands.
- `ask-matt` is the map from idea to shipped product. When I describe something to build, change, fix or explore, read `~/.claude/skills/ask-matt/SKILL.md`, pick the step that fits, and run it: read that skill's SKILL.md and follow it yourself, user-invoked skills included. When a step ends, go on to the next one on the map.
- Say in one line which skill you are running. Ask me only what that skill asks; my answers are the decisions.
- Project setup is yours too: when the session context lists capsule gaps, fix them with `project-setup` without asking.

## Project guidance
- If `VISION.md` exists at the repo root, read it before planning, designing or reviewing. When a principle decides a trade-off, name the principle.
- If `GLOSSARY.md` or `docs/adr/` exist, read them and use their vocabulary.

## Orca owns worktrees and tasks
- Load the `orca-cli` skill before any worktree, terminal, browser or board operation.
- Create every worktree through Orca. Never run `git worktree add`; never use `.claude/worktrees`.
- A ticket is an issue in the project's tracker (`docs/agents/issue-tracker.md`). A workspace is where one ticket is worked on: create it when work on the ticket starts, linked to its issue, never to hold a ticket for later.
- The tracker and the Workspace Board are the only task lists; TODO lists stay out of files, docs and the vault.
- Keep the card status true:

  | Event | Status |
  |---|---|
  | starting work; changes requested | `in-progress` |
  | PR (Pull Request) opened; waiting for my review | `in-review` |
  | merged or finished | `completed` |

- Update the card comment at every checkpoint: a slice finished, a hypothesis confirmed or refuted, a review done, a blocker hit. Read it first with `orca worktree current --json` and keep any goal or constraint I wrote. Line 1: what happened and what is next. Line 2: `goal: …`.
- Remove a worktree only when I ask.

## Git
- Default: a branch in an Orca worktree, then a pull request.
- When I say "on main" or "directly", commit to main without a PR.
- Write commit messages as conventional commits (`feat`, `fix`, `chore`…).
- Do every GitHub operation with the `gh` CLI (Command Line Interface) and every GitLab operation with the `glab` CLI.
- Never force-push main. Ask before discarding uncommitted work.

## Review gate
Before opening a PR, do step 1, then step 2. When I ask for a review and no PR is being opened, do only step 2.

1. Gather proof that the change works. Write the PR body with the `pr` skill and put the proof in its Evidence section. When no proof is possible, write there in one line why not.

   | Kind of change | Proof |
   |---|---|
   | bug fix | test output: the new test failing before the change and passing after |
   | logic or a script | output of the tests that cover the change |
   | UI (User Interface) | a screenshot or recording of the running app |
   | CLI (Command Line Interface), hook, server, API (Application Programming Interface) | the command or request that was run, and its output |
   | build, CI (Continuous Integration), config | output of the build or the check command, run on this machine |
   | docs or instructions only | run any command the text names; when there is none, no proof is possible |
   | anything else | the closest of the above: output that shows the changed thing working |

   A change of several kinds gets proof for each kind.

2. Run `/code-review` and the specialists from the table below in one parallel batch, then merge, dedupe and rank the findings. Do this on every PR, even with good proof: the agents check what tests cannot and what needs judgment. When a finding leads to a change in the code, gather the proof again.

Specialists by what changed:

| Changed | Agent |
|---|---|
| `*.py` | python-reviewer |
| `*.ts` `*.tsx` `*.js` `*.jsx` | typescript-reviewer |
| `*.swift` | swift-reviewer |
| anything else | code-reviewer |
| auth, input handling, secrets, network, dependencies, IaC (Infrastructure as Code) | + security-reviewer |
| error handling, retries, fallbacks | + silent-failure-hunter |
| new or changed tests | + pr-test-analyzer |

- Build failure → build-error-resolver (Swift, Xcode, SPM (Swift Package Manager) → swift-build-resolver).
- Slow path or memory concern → performance-optimizer.
- Cleanup after implementation, when I ask → code-simplifier.

## Knowledge base
- Each project has its own vault; the session-start context names its path. Before non-trivial work, read the vault's `wiki/index.md` and `wiki/overview.md`.
- `wiki/` is written only by the `wiki-ingest` and `wiki-lint` skills. When I say "note this" or "remember this", append a dated note to the vault's `raw/inbox/`.
- Session capture is automatic. End sessions without a closing command.
