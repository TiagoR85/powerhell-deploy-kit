function Copy-Artifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$StateRoot
    )
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw (New-DeployError -Code DEPLOY_SOURCE_INVALID -Message "Source path does not exist: $SourcePath")
    }
    $item = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop

    if ($item.PSIsContainer) {
        $contentRoot = $SourcePath
    }
    elseif ($item.Extension -ieq '.zip') {
        $staging = Join-Path $StateRoot 'staging'
        if (Test-Path -LiteralPath $staging) {
            Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction Stop
        }
        New-Item -ItemType Directory -Path $staging -Force -ErrorAction Stop | Out-Null
        Expand-Archive -LiteralPath $SourcePath -DestinationPath $staging -Force -ErrorAction Stop
        $contentRoot = $staging
    }
    else {
        throw (New-DeployError -Code DEPLOY_SOURCE_INVALID -Message "Source must be a directory or a .zip file: $SourcePath")
    }

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force -ErrorAction Stop | Out-Null
    }
    Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction Stop |
        Where-Object { $_.Name -ne '.deploy' } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        }
    Get-ChildItem -LiteralPath $contentRoot -Force -ErrorAction Stop |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $TargetPath -Recurse -Force -ErrorAction Stop
        }
}
