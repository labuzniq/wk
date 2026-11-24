# Checks

Checks are rules that code runs, so a mistake is caught where it is made. `mise run lint` runs all of them.

## `starter/`

The starter checks: a small set per stack, aimed at the first mistakes a coding agent makes. `wk adopt` wrote them. For each stack there are two files:

- the config for the linter (`python.toml` for ruff, `ts.json` for Biome, `swift.yml` for SwiftLint),
- a `.txt` file with one line per check: what the real problem is and how to fix it. The lint task prints it when a starter check fails.

`wk adopt` only creates a file here when it is missing. It never changes one that is there, so you can remove a rule that does not fit this project.

## This project's own checks

Put them in this folder, beside `starter/`, or in the config of the linter the project already uses. Add the command that runs them to the lint task in `mise.toml`. `wk adopt` does not touch them.

Give each check a message that says what the real problem is and how to fix it.
