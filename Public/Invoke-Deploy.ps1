function Invoke-Deploy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath,
        [uri]$HealthUrl,
        [ValidateRange(1, 100)][int]$HealthRetries = 5,
        [ValidateRange(0, 60)][int]$HealthDelaySeconds = 2,
        [string]$StateRoot
    )
    throw 'Invoke-Deploy: not implemented (Task 7)'
}
