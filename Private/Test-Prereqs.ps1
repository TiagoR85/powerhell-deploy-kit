function Get-NearestExistingPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $current = $Path
    while (-not [string]::IsNullOrEmpty($current)) {
        if (Test-Path -LiteralPath $current) { return $current }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { return $null }
        $current = $parent
    }
    return $null
}

function Test-StateRootWritable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StateRootPath)
    if ($StateRootPath.Length -gt 3) {
        $StateRootPath = $StateRootPath.TrimEnd([char[]]@('\', '/'))
    }
    $base = Get-NearestExistingPath -Path $StateRootPath
    if ([string]::IsNullOrEmpty($base)) { return $false }

    $probeDir = $base
    if ((Split-Path -Leaf $StateRootPath) -eq '.deploy' -and (Split-Path -Leaf $base) -ne '.deploy') {
        $probeDir = Join-Path $base '.deploy'
    }
    $created = $false
    try {
        if (-not (Test-Path -LiteralPath $probeDir)) {
            New-Item -ItemType Directory -Path $probeDir -Force -ErrorAction Stop | Out-Null
            $created = $true
        }
        $probe = Join-Path $probeDir '.probe'
        Set-Content -LiteralPath $probe -Value 'ok' -Encoding ASCII -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($created) {
            Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-SourceSize {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSIsContainer) {
        $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0) { return [long]0 }
        return [long]($files | Measure-Object -Property Length -Sum).Sum
    }
    return [long]$item.Length
}

function Test-Prereqs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath,
        [uri]$HealthUrl,
        [string]$StateRoot
    )
    $failures = @()

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        $failures += "Source not found: $SourcePath"
    }

    if (Test-Path -LiteralPath $TargetPath) {
        $targetItem = Get-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $targetItem -and -not $targetItem.PSIsContainer) {
            $failures += "Target exists and is not a directory: $TargetPath"
        }
    }

    $stateRootPath = Get-DeployStateRoot -TargetPath $TargetPath -StateRoot $StateRoot
    if (-not (Test-StateRootWritable -StateRootPath $stateRootPath)) {
        $failures += "State location is not writable: $stateRootPath"
    }

    if ($failures.Count -eq 0) {
        $required = [long](Get-SourceSize -Path $SourcePath) * 2
        if ($required -lt 100MB) { $required = [long]100MB }
        try {
            $driveName = (Split-Path -Qualifier -Path $TargetPath).TrimEnd(':')
            $drive = Get-PSDrive -Name $driveName -ErrorAction Stop
            if ($drive.Free -lt $required) {
                $failures += "Insufficient free space on ${driveName}: need $([math]::Round($required / 1MB)) MB, free $([math]::Round($drive.Free / 1MB)) MB"
            }
        }
        catch {
            $failures += "Free space check failed: $($_.Exception.Message)"
        }
    }

    if ($null -ne $HealthUrl) {
        $port = if ($HealthUrl.Port -gt 0) { $HealthUrl.Port } elseif ($HealthUrl.Scheme -eq 'https') { 443 } else { 80 }
        $reachable = $false
        try {
            $reachable = Test-NetConnection -ComputerName $HealthUrl.Host -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
        }
        catch {
            $reachable = $false
        }
        if (-not $reachable) {
            $failures += "Health URL is not reachable: $HealthUrl"
        }
    }

    [pscustomobject]@{
        Passed   = ($failures.Count -eq 0)
        Failures = $failures
    }
}
