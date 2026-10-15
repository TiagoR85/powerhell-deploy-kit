function Get-DeployHistory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [ValidateRange(1, 10000)][int]$Last = 10,
        [string]$StateRoot
    )
    throw 'Get-DeployHistory: not implemented (Task 2)'
}
