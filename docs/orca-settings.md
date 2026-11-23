# Orca settings to set by hand (once)

1. Open Orca → Settings → Agents. Check that "Agent status hooks" is on.
2. Open Settings → Experimental. Turn on "Orchestration" and "Agent Dashboard".
3. Open the Workspace Board → its settings menu. If "Sync board status with agent turns" exists, turn it off.

Not needed: registering the Orca CLI (Command Line Interface), and a setup command per repository. The CLI is registered, and each project carries its setup command in `orca.yaml`.
