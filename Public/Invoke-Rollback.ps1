function Invoke-Rollback {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$BackupPath,
        [string]$StateRoot
    )
    throw 'Invoke-Rollback: not implemented (Task 8)'
}
