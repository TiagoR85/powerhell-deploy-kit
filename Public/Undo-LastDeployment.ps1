function Undo-LastDeployment {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$StateRoot
    )
    $target = Resolve-DeployPath -Path $TargetPath
    if (-not (Test-Path -LiteralPath $target)) {
        throw (New-DeployError -Code TARGET_NOT_FOUND -Message "Target path does not exist: $target")
    }
    $history = @(Get-DeployHistory -TargetPath $target -Last 100 -StateRoot $StateRoot)
    $candidate = $history |
        Where-Object { $_.Status -eq 'Succeeded' -and -not [string]::IsNullOrWhiteSpace([string]$_.BackupPath) } |
        Select-Object -First 1
    if ($null -eq $candidate) {
        throw (New-DeployError -Code ROLLBACK_NOT_FOUND `
            -Message "No deployment with a backup found in history for $target")
    }
    if (-not $PSCmdlet.ShouldProcess($target, "Undo last deployment using backup $($candidate.BackupPath)")) { return }
    Invoke-Rollback -TargetPath $target -BackupPath $candidate.BackupPath -StateRoot $StateRoot
}
