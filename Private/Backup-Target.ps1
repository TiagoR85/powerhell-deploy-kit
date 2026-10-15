function Backup-Target {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$StateRoot
    )
    if (-not (Test-Path -LiteralPath $TargetPath)) { return $null }

    $backupsRoot = Join-Path $StateRoot 'backups'
    $stamp = Get-DeployTimestamp
    $backupPath = Join-Path $backupsRoot $stamp
    $suffix = 1
    while (Test-Path -LiteralPath $backupPath) {
        $backupPath = Join-Path $backupsRoot ('{0}-{1}' -f $stamp, $suffix)
        $suffix++
    }
    New-Item -ItemType Directory -Path $backupPath -Force -ErrorAction Stop | Out-Null

    Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction Stop |
        Where-Object { $_.Name -ne '.deploy' } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $backupPath -Recurse -Force -ErrorAction Stop
        }
    return $backupPath
}

function Restore-TargetBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BackupPath,
        [Parameter(Mandatory)][string]$TargetPath
    )
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        throw (New-DeployError -Code ROLLBACK_NOT_FOUND -Message "Backup not found: $BackupPath")
    }
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force -ErrorAction Stop | Out-Null
    }
    Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction Stop |
        Where-Object { $_.Name -ne '.deploy' } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        }
    Get-ChildItem -LiteralPath $BackupPath -Force -ErrorAction Stop |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $TargetPath -Recurse -Force -ErrorAction Stop
        }
}
