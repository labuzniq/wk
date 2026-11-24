# Vision

<!-- vision: author-approved 2026-11-23 -->

`wk` exists so that every project starts and runs the same way, without its owner typing setup commands, and so that the agent's work can be trusted without reading every line.
It serves a developer who works on a Mac with Orca and a coding agent, and it turns "open a folder and say what you want" into a prepared project, a true task board and a growing wiki.
It owns exactly one thing: the wiring between Orca, the agent and a project folder - hooks, the `wk` commands, templates, a starter set of checks and three small skills.

## The owner talks, the agent runs the flow

The owner types no slash commands and no setup commands.
The agent prepares a project on first open and fixes capsule gaps itself.
When a step is easy to see and easy to undo, the agent does it and reports in one line instead of asking.
An existing repo gets its capsule on a branch with a pull request; closing that pull request is the remembered "no".
In a project that opts in with a flag, the agent merges its own pull request when every check passes, proof is attached and the review agents raise nothing above low; otherwise the card waits for the owner.
The vision stays the owner's to approve.
A change that adds a step the owner must type or remember is a step backwards.

## Checks before prose

Trust in the agent is built in this order: project design that makes a mistake hard to write, then checks that code runs, then proof that the change works, and prose instructions last.
A correction the owner has made in three sessions becomes a check - a lint rule, a test, a hook or a `wk doctor` line - committed on its own, with the way to revert it named.
It becomes a line in the project's instructions only when no check can express it.
When the same correction shows up in three projects, the check or the line lands in this repo instead, the same way.
A check's message says what the real problem is and how to fix it, so the agent meets the guidance where it fails.
A rule that a check now enforces is removed from the instructions; the global instructions hold only what a hook cannot check.
The capsule gives each stack a starter set of checks, and a project's own corrections add to it.
Before a pull request, review starts from proof - test output, a run of the app, a screenshot - and the pinned review agents always run after it, for what tests cannot cover and what needs judgment.
An automation is built only on top of a step that already works without hand correction; automating a weak step only makes more weak output.
The kit holds itself to this: its own scripts get tests, shell lint and a `wk doctor` run against a scratch project before any new automation is built on them.

## Orca owns worktrees and tasks

Every worktree is created through Orca.
Every task is one issue in the project's tracker, and work on it happens in one Orca workspace, created when the work starts and linked to the issue.
There is no fallback and no mode without Orca: when Orca is not running, creating a worktree fails on purpose.
The tracker is the source of truth for tickets, and the board for work in progress; task state stays out of docs and the wiki.
A workspace follows its issue: a merged pull request closes the issue, and a close or a comment on the issue reaches the workspace card.
Card status follows facts - commits and pull request state - and a completed card is never moved back.
A worktree is removed without asking only when its branch is merged and its card has been completed for 14 days; the branch and the card stay.

## Wiring, not content

Skills and agents written by other people are installed from their own repos; this repo holds no forks and no copies of their text.
Agents are pinned to one commit, with a lock file of checksums.
A skill or an agent may carry a small patch when its text does not fit this setup; the patch is a file in this repo and the lock file records the result.
Pins move by automation: a scheduled run offers the newer versions as a pull request, and merges it itself when `wk doctor` passes, every patch still applies and the upstream change is under 50 lines; a bigger change waits for the owner.

## Keep what is already there

`wk adopt` and the installer can run again at any time: they create what is missing, leave existing files untouched, and back up whatever they replace.
Every run prints what it created, kept, linked or replaced.
Wiki automations commit inside their vault only, and they do not push.

## Checked facts, fast hooks

A claim about Orca or an agent is tested on a real machine, or marked as "read in docs" or "open", in `docs/verified.md`.
When reality differs from the plan, the kit follows reality and writes the difference down.
Hooks that run in every session stay fast: no network calls and no waiting on Orca; a slow answer is cached and refreshed in the background.

## One home per kind of knowledge

Tickets live in the tracker, work in progress on the board, decisions in `docs/adr/`, specs in `docs/specs/`, and what was learned in a vault.
Each project has its own vault, inside its own repo, for what is true of that project.
Lessons that hold across projects - about Orca, the agents and the kit itself - live in one shared vault outside any repo.
Sorting lessons between the two and keeping both in order runs as Orca automations driven by the agent, never as a chore for the owner.
Raw sources are add-only, and wiki pages are written only by the wiki skills, with a source for every claim.

## Scope

`wk` is not a task tracker, not a worktree manager, and not a library of skills or agents.
It targets macOS and Orca, with Claude Code and Codex as agents, and the Python, TypeScript and Swift stacks.
It is one setup that more than one person can install.
What differs between people is a flag or a personal file outside the repo; what a capsule commits to a shared repo works for everyone who clones it.
Private material stays out of this repo: the build spec, project names and vault contents live elsewhere.

A change aligns when it removes something the owner had to type or remember, turns a repeated correction into a check, can be seen and undone, keeps third-party text out of this repo and existing files untouched, and rests on a checked fact.
A change should be resisted when it adds a task list outside the tracker and the board, a workspace for a ticket nobody is working on, a second home for a kind of knowledge, a way around Orca, a fork or copy of someone else's skill, a slow or networked step in a hook, a prose rule where a check would do, automation on top of a step that still needs hand correction, or a silent change that cannot be undone.
