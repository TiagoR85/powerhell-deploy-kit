function Write-DeployHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Record,
        [Parameter(Mandatory)][string]$HistoryPath
    )
    $directory = Split-Path -Parent $HistoryPath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }
    $json = ConvertTo-Json -InputObject $Record -Compress
    [System.IO.File]::AppendAllText($HistoryPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}
