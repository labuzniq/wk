# Issue tracker: Orca Workspace Board

Tickets for this repo are Orca workspace cards. One ticket = one card = one worktree. Load the `orca-cli` skill before any command below. The repo id is `orca_repo_id` in `.workspace-kit.toml`.

## Conventions

- The spec is `docs/specs/<spec-slug>.md`, with one `## <ticket-slug>` section per ticket. Acceptance criteria and design live there, never on the card.
- Card state is two fields: the status (`todo`, `in-progress`, `in-review`, `completed`) and the comment.
- Comment format, one item per line:

  ```
  <what just happened; what is next>
  goal: <one line>
  spec: docs/specs/<spec-slug>.md#<ticket-slug>
  triage: <role>
  blocked-by: <card names, if any>
  follow-ups: <short items found later, if any>
  ```

- A blocked card keeps its status; its first comment line starts with `BLOCKED:`.

## When a skill says "publish to the issue tracker"

Write the spec to `docs/specs/<spec-slug>.md`. For each ticket, create a card and set it to `todo`:

```
orca worktree create --repo id:<repoId> --name <ticket-slug> --no-parent --setup skip --json
orca worktree set --worktree id:<id from the create result> --workspace-status todo --comment "<comment in the format above>" --json
```

## When a skill says "fetch the relevant ticket"

`orca worktree list --repo id:<repoId> --json` lists every card with its status and comment. Read the section the card's `spec:` line points to.

## When a skill says "close the ticket"

`orca worktree set --worktree id:<id> --workspace-status completed --json`. Keep the worktree; removing it is the user's call.

## Triage labels

The five triage roles are recorded on the `triage:` comment line, with these statuses:

| Role | Status |
|---|---|
| `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human` | `todo` |
| `wontfix` | `completed` |

## Wayfinding operations

Used by `/wayfinder`. The **map** is `docs/specs/<effort>-map.md`; each **child** ticket is a card.

- **Blocking**: the `blocked-by:` comment line. A card is unblocked when every card it names is `completed`.
- **Frontier**: cards that are `todo` and unblocked; oldest first.
- **Claim**: set the card to `in-progress` before any work.
- **Resolve**: write the answer into the map's Decisions-so-far, then set the card to `completed`.
