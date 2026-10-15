function Get-DeployHistory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [ValidateRange(1, 10000)][int]$Last = 10,
        [string]$StateRoot
    )
    $state = Get-DeployStateRoot -TargetPath $TargetPath -StateRoot $StateRoot
    $historyPath = Join-Path $state 'history.json'
    if (-not (Test-Path -LiteralPath $historyPath)) {
        return @()
    }
    $records = New-Object System.Collections.Generic.List[object]
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $historyPath -ErrorAction Stop) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $record = ConvertFrom-Json -InputObject $line -ErrorAction Stop
            # PS 7 ConvertFrom-Json parses ISO strings into [datetime] (7 fractional
            # digits); normalize back to the invariant 3-digit ISO contract so both
            # shells round-trip identically.
            if ($record.Timestamp -is [datetime]) {
                $record.Timestamp = $record.Timestamp.ToString(
                    'yyyy-MM-ddTHH:mm:ss.fff',
                    [System.Globalization.CultureInfo]::InvariantCulture)
            }
            $records.Add($record)
        }
        catch {
            throw (New-DeployError -Code HISTORY_CORRUPT -Message "Invalid JSON at line $lineNumber of $historyPath")
        }
    }
    $records.Reverse()
    if ($records.Count -gt $Last) {
        return $records.GetRange(0, $Last).ToArray()
    }
    return $records.ToArray()
}
