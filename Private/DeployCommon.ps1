function Resolve-DeployPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Get-DeployStateRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$StateRoot
    )
    if (-not [string]::IsNullOrWhiteSpace($StateRoot)) {
        return Resolve-DeployPath -Path $StateRoot
    }
    return Join-Path (Resolve-DeployPath -Path $TargetPath) '.deploy'
}

function Get-DeployTimestamp {
    [CmdletBinding()]
    param()
    (Get-Date).ToString('yyyyMMdd-HHmmss-fff', [System.Globalization.CultureInfo]::InvariantCulture)
}

function New-DeployError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message
    )
    [System.InvalidOperationException]::new("[$Code] $Message")
}

function New-DeployRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][ValidateSet('Succeeded', 'RolledBack', 'Failed')][string]$Status,
        [string]$BackupPath = '',
        [bool]$HealthChecked = $false,
        [int]$DurationMs = 0,
        [string]$ErrorMessage = ''
    )
    [pscustomobject]@{
        Id            = [guid]::NewGuid().ToString()
        Timestamp     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fff', [System.Globalization.CultureInfo]::InvariantCulture)
        TargetPath    = $TargetPath
        Status        = $Status
        BackupPath    = $BackupPath
        HealthChecked = $HealthChecked
        DurationMs    = $DurationMs
        Error         = $ErrorMessage
    }
}
