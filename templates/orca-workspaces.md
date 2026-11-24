
## Orca workspaces

A **ticket** is an issue in the tracker described above. A **workspace** is an Orca worktree where one ticket is being worked on. A workspace is never created to hold a ticket: a ticket nobody is working on has no workspace.

Load the `orca-cli` skill before any command below. Name the repo by the path of its primary checkout, the first line of `git worktree list`.

- **Specs** stay in the repo: `docs/specs/<spec-slug>.md`, with one `## <ticket-slug>` section per ticket. This replaces any line above that puts specs in the tracker or under `.scratch/`. The ticket links to its section; acceptance criteria and design live in the spec.
- **Publish tickets**: write the spec, then create one issue per ticket as described above. Create no workspace.
- **Start work on a ticket**: claim the ticket first (GitHub and GitLab: assign it to yourself; local files: set its status), then create its workspace, linked to the issue. For GitHub:

  ```
  orca worktree create --repo path:<primary checkout> --name <ticket-slug> --no-parent --issue <number> --json
  ```

  For GitLab use `--gitlab-issue <number>`. For local ticket files, leave the link flag out and name the file on the `ticket:` line of the comment.
- **A blocked ticket gets no workspace.** Blocking lives in the tracker, as described above.
- **Workspace comment**, one item per line:

  ```
  <what just happened; what is next>
  goal: <one line>
  ticket: <issue number or ticket file>
  spec: docs/specs/<spec-slug>.md#<ticket-slug>
  follow-ups: <short items found later, if any>
  ```

- **Finish**: the pull request (GitLab: merge request) body says `Closes #<number>`, so the merge closes the ticket; a local ticket file is closed by hand as described above. `wk board-sync` moves the workspace to `completed`. Do not remove the workspace yourself: the daily `Worktree cleanup` automation removes it once its branch is merged and its card has been completed for 14 days, and keeps the branch.
