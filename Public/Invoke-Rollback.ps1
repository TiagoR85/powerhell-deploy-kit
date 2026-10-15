function Invoke-Rollback {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$BackupPath,
        [string]$StateRoot
    )
    $target = Resolve-DeployPath -Path $TargetPath
    $backup = Resolve-DeployPath -Path $BackupPath
    if (-not (Test-Path -LiteralPath $target)) {
        throw (New-DeployError -Code TARGET_NOT_FOUND -Message "Target path does not exist: $target")
    }
    if (-not $PSCmdlet.ShouldProcess($target, "Restore backup $backup")) { return }

    $state = Get-DeployStateRoot -TargetPath $target -StateRoot $StateRoot
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Restore-TargetBackup -BackupPath $backup -TargetPath $target
    $stopwatch.Stop()
    $record = New-DeployRecord -TargetPath $target -Status 'RolledBack' -BackupPath $backup `
        -DurationMs $stopwatch.ElapsedMilliseconds
    Write-DeployHistory -Record $record -HistoryPath (Join-Path $state 'history.json')
}
