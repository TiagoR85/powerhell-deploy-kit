# ADR-0001: Support Windows PowerShell 5.1 and PowerShell 7+

## Status

Accepted

## Context

The module targets operational Windows machines where the default shell is still Windows PowerShell 5.1, while developers increasingly use PowerShell 7.x. A single codebase must behave identically on both. Pre-flight probes confirmed the local machine has only 5.1, so 7.x compatibility is proven by the CI matrix, not local runs.

## Decision

Support Windows PowerShell 5.1 and PowerShell 7+ from the same code:

- No PS 7-only syntax: no `??`, no ternary `? :`, no `&&` / `||` pipeline chains, no multi-segment `Join-Path` (3+ arguments).
- Every mutating cmdlet call carries an explicit `-ErrorAction Stop`.
- No module-level `$StrictMode` or `$ErrorActionPreference` changes, so importing the module never alters consumer behavior.
- Invariants are verified by a CI matrix that runs the full suite under both `powershell` (5.1) and `pwsh` (7.x) on `windows-latest`.

## Consequences

- Slightly more verbose code (nested `Join-Path`, explicit error handling).
- JSON parsing differences between shells must be normalized in code (see ADR-0002 and `Get-DeployHistory` timestamp handling).
- Local development can only smoke-test 5.1; 7.x regressions are caught by CI before merge.
