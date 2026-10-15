# powerhell-deploy-kit

Atomic folder/.zip deployments with backup, health check, JSON Lines history, and rollback — no IIS or Windows Services dependency.

[![CI](https://github.com/TiagoR85/powerhell-deploy-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/TiagoR85/powerhell-deploy-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## About this repository

`powerhell-deploy-kit` is a small PowerShell module for deploying a folder or `.zip` artifact to a target directory:

- Prerequisite checks before anything is touched (source, target, disk space, state writability).
- Automatic backup of the current target content before the swap.
- Optional HTTP health check with retries; automatic rollback when it fails.
- Append-only JSON Lines deployment history next to the target.
- Manual rollback to any backup, or one-command undo of the last successful deployment.

It is **not** a release pipeline, IIS manager, or Windows Services controller. It never stores or transmits secrets; it only moves files and records metadata.

## Requirements

- Windows PowerShell 5.1 **or** PowerShell 7+
- Development only: Pester 6, PSScriptAnalyzer

## Install

```powershell
git clone https://github.com/TiagoR85/powerhell-deploy-kit.git
Import-Module .\powerhell-deploy-kit\powerhell-deploy-kit.psd1
```

## Quickstart

```powershell
Import-Module .\powerhell-deploy-kit.psd1
$target = '.\demo-app'
$src = '.\demo-src'
New-Item -ItemType Directory -Path $src -Force | Out-Null
Set-Content -Path (Join-Path $src 'index.html') -Value '<h1>v1</h1>'
# Seed the target so the deploy takes a backup (undo restores the previous content).
New-Item -ItemType Directory -Path $target -Force | Out-Null
Set-Content -Path (Join-Path $target 'index.html') -Value '<h1>v0</h1>'

Test-DeploymentPrereqs -SourcePath $src -TargetPath $target   # .Passed / .Failures
Invoke-Deploy -SourcePath $src -TargetPath $target            # -WhatIf supported
Invoke-Deploy -SourcePath $src -TargetPath $target -HealthUrl http://127.0.0.1:8080/health
Get-DeployHistory -TargetPath $target -Last 5
Undo-LastDeployment -TargetPath $target                       # back to v0
```

## Commands

| Command | Parameters | Purpose |
| --- | --- | --- |
| `Test-DeploymentPrereqs` | `-SourcePath` `-TargetPath` `-HealthUrl` `-StateRoot` | Dry validation; returns `.Passed` + `.Failures` |
| `Invoke-Deploy` | `-SourcePath` `-TargetPath` `-HealthUrl` `-HealthRetries` `-HealthDelaySeconds` `-StateRoot` `-WhatIf` | Backup, atomic swap, optional health check, auto-rollback on failure |
| `Get-DeployHistory` | `-TargetPath` `-Last` `-StateRoot` | Newest-first JSON Lines history (default last 10) |
| `Invoke-Rollback` | `-TargetPath` `-BackupPath` `-StateRoot` `-WhatIf` | Restore one backup and record a `RolledBack` entry |
| `Undo-LastDeployment` | `-TargetPath` `-StateRoot` `-WhatIf` | Restore the backup of the newest successful deploy |

## Error codes

| Code | Meaning |
| --- | --- |
| `DEPLOY_PREREQ_FAILED` | A prerequisite check failed; nothing was changed |
| `DEPLOY_HEALTH_FAILED` | Health check failed after the artifact was copied |
| `DEPLOY_SOURCE_INVALID` | Source is missing or is neither a directory nor a `.zip` |
| `ROLLBACK_NOT_FOUND` | No matching backup / no suitable history record |
| `TARGET_NOT_FOUND` | Target path does not exist |
| `HISTORY_CORRUPT` | A history line is not valid JSON |

## State layout

State lives next to the target so it travels with the artifact folder:

```
<target>/.deploy/
  backups/    # one folder per backup (previous target content, .deploy excluded)
  staging/    # temporary .zip extraction area
  history.json  # append-only JSON Lines, UTF-8, no BOM
```

Use `-StateRoot` to place state elsewhere (e.g. read-only targets). Backups never include the `.deploy` directory itself.

## Development

```powershell
.\scripts\Invoke-Tests.ps1                    # PSScriptAnalyzer + Pester + coverage gate
.\scripts\Invoke-Tests.ps1 -MinimumCoverage 85
```

CI runs the same script on a `windows-latest` matrix for both `powershell` (5.1) and `pwsh` (7.x). Coverage is measured on `Public/` and `Private/` and gated at 80%.

## Documentation

- [ADR-0001 — Support Windows PowerShell 5.1 and PowerShell 7+](docs/adr/ADR-0001-powershell-5-1-and-7-x.md)
- [ADR-0002 — JSON Lines append-only history](docs/adr/ADR-0002-json-lines-history.md)
- [ADR-0003 — State lives next to the target](docs/adr/ADR-0003-state-next-to-target.md)

## License

[MIT](LICENSE)
