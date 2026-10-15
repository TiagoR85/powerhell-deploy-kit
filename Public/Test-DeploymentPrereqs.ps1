function Test-DeploymentPrereqs {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath,
        [uri]$HealthUrl,
        [string]$StateRoot
    )
    throw 'Test-DeploymentPrereqs: not implemented (Task 3)'
}
