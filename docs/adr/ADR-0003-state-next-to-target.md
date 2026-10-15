# ADR-0003: State lives next to the target

## Status

Accepted

## Context

Deploy state (backups, staging, history) has to be findable at rollback time without global configuration. Options considered: Windows registry, a central per-user store, and a directory next to the deployed artifact.

## Decision

Keep state in `<target>/.deploy` by default:

- `backups/` holds one folder per pre-deploy snapshot; the `.deploy` directory itself is excluded from snapshots to avoid recursion.
- `staging/` is the temporary extraction area for `.zip` sources.
- `history.json` is the JSON Lines store (ADR-0002).
- `-StateRoot` overrides the location for read-only targets or shared state roots; the same override is accepted by every public command.

## Consequences

- State travels with the artifact folder: copying or archiving the target keeps its deploy history and backups.
- No registry entries, no hidden per-user stores, nothing to clean on uninstall.
- Operators must ensure `<target>/.deploy` is writable (or pass `-StateRoot`); `Test-DeploymentPrereqs` verifies this with a create/write/delete probe before any deploy.
