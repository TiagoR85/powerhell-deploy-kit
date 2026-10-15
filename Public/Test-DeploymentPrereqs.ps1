function Test-DeploymentPrereqs {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath,
        [uri]$HealthUrl,
        [string]$StateRoot
    )
    Test-Prereqs -SourcePath (Resolve-DeployPath -Path $SourcePath) `
        -TargetPath (Resolve-DeployPath -Path $TargetPath) `
        -HealthUrl $HealthUrl `
        -StateRoot $StateRoot
}
