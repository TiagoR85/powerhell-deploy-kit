function Invoke-Deploy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath,
        [uri]$HealthUrl,
        [ValidateRange(1, 100)][int]$HealthRetries = 5,
        [ValidateRange(0, 60)][int]$HealthDelaySeconds = 2,
        [string]$StateRoot
    )
    $source = Resolve-DeployPath -Path $SourcePath
    $target = Resolve-DeployPath -Path $TargetPath
    $state = Get-DeployStateRoot -TargetPath $target -StateRoot $StateRoot

    $check = Test-Prereqs -SourcePath $source -TargetPath $target -HealthUrl $HealthUrl -StateRoot $StateRoot
    if (-not $check.Passed) {
        throw (New-DeployError -Code DEPLOY_PREREQ_FAILED -Message ($check.Failures -join '; '))
    }

    if (-not $PSCmdlet.ShouldProcess($target, "Deploy artifact from $source")) { return }

    $historyPath = Join-Path $state 'history.json'
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $backupPath = $null
    $backupTaken = $false
    $healthChecked = $false
    try {
        $backupPath = Backup-Target -TargetPath $target -StateRoot $state
        $backupTaken = ($null -ne $backupPath)
        Copy-Artifact -SourcePath $source -TargetPath $target -StateRoot $state
        if ($null -ne $HealthUrl) {
            $healthChecked = $true
            if (-not (Invoke-HealthCheck -Uri $HealthUrl -Retries $HealthRetries -DelaySeconds $HealthDelaySeconds)) {
                throw (New-DeployError -Code DEPLOY_HEALTH_FAILED `
                    -Message "Health check failed after $HealthRetries attempt(s): $HealthUrl")
            }
        }
        $stopwatch.Stop()
        $record = New-DeployRecord -TargetPath $target -Status 'Succeeded' -BackupPath $backupPath `
            -HealthChecked $healthChecked -DurationMs $stopwatch.ElapsedMilliseconds
        Write-DeployHistory -Record $record -HistoryPath $historyPath
    }
    catch {
        $stopwatch.Stop()
        $original = $_
        $status = 'Failed'
        if ($backupTaken) {
            try {
                Restore-TargetBackup -BackupPath $backupPath -TargetPath $target
                $status = 'RolledBack'
            }
            catch {
                $status = 'Failed'
                Write-Verbose "Auto-rollback failed: $($_.Exception.Message)"
            }
        }
        $record = New-DeployRecord -TargetPath $target -Status $status -BackupPath $backupPath `
            -HealthChecked $healthChecked -DurationMs $stopwatch.ElapsedMilliseconds `
            -ErrorMessage $original.Exception.Message
        try {
            Write-DeployHistory -Record $record -HistoryPath $historyPath
        }
        catch {
            Write-Verbose "History write failed after error: $($_.Exception.Message)"
        }
        throw $original
    }
}
