# ADR-0002: JSON Lines append-only history

## Status

Accepted

## Context

Deployments need a durable audit trail: what was deployed, when, from where, and whether a backup exists. The store must survive crashes mid-write, work without external dependencies, and stay debuggable by operators on the target machine.

## Decision

Store history as JSON Lines (one compact JSON object per line) in `<state>/history.json`:

- Append-only writes via `[System.IO.File]::AppendAllText` (UTF-8, no BOM); the file is never rewritten in place, so a crash cannot destroy earlier records.
- One record per deploy/rollback with stable fields: `Timestamp` (invariant ISO `yyyy-MM-ddTHH:mm:ss.fff`), `TargetPath`, `Status` (`Succeeded` / `RolledBack` / `Failed`), `BackupPath`, `HealthChecked`, `DurationMs`, `Error`.
- Readers validate line-by-line; an invalid line yields `HISTORY_CORRUPT` with the line number instead of failing silently.
- Records are read newest-first (reversed on read), trimmed to `-Last`.

## Consequences

- Appends are resilient, but compaction/pruning is not implemented (YAGNI for v1).
- Consumers get human-greppable history (`Select-String`, `Get-Content | ConvertFrom-Json`) without tooling.
- PS 7's `ConvertFrom-Json` parses ISO strings into `[datetime]` (7 fractional digits); `Get-DeployHistory` normalizes back to the 3-digit invariant string so both shells round-trip identically.
