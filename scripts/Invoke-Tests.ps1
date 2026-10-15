# Test entrypoint: PSScriptAnalyzer (errors fail) -> Pester -> coverage gate.
# Suppressed rules: PSUseDeclaredVarsMoreThanAssignments (test scaffolding vars).
# Coverage is measured on module sources only (Public/), (Private/) - Pester 6
# disables CodeCoverage by default, so the gate must enable it explicitly.
[CmdletBinding()]
param(
    [string]$Path,
    [ValidateRange(0, 100)][double]$MinimumCoverage = 80
)
$ErrorActionPreference = 'Stop'

# $PSScriptRoot is empty while param defaults are evaluated (PS 5.1 -File), so
# the default path is resolved here, inside the script body.
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path (Join-Path $PSScriptRoot '..') 'Tests'
}
$solutionRoot = Split-Path -Parent $PSScriptRoot

Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Host: $((Get-Process -Id $PID).ProcessName)"

Write-Host '== PSScriptAnalyzer =='
$analyzer = Invoke-ScriptAnalyzer -Path $solutionRoot -Recurse -ExcludeRule 'PSUseDeclaredVarsMoreThanAssignments'
$analyzer | Format-Table -AutoSize | Out-String | Write-Host
$analyzerErrors = @($analyzer | Where-Object Severity -eq 'Error')
if ($analyzerErrors.Count -gt 0) {
    Write-Host "ERROR: PSScriptAnalyzer found $($analyzerErrors.Count) error(s)."
    exit 1
}

Write-Host '== Pester =='
$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Run.PassThru = $true
$config.Run.Exit = $false
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = Join-Path $solutionRoot 'TestResults.xml'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @(
    (Join-Path $solutionRoot 'Public'),
    (Join-Path $solutionRoot 'Private')
)
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = Join-Path $solutionRoot 'coverage.xml'
$result = Invoke-Pester -Configuration $config

Write-Host ("Passed: {0}  Failed: {1}  NotRun: {2}" -f $result.PassedCount, $result.FailedCount, $result.NotRunCount)
$coverage = [double]$result.CodeCoverage.CoveragePercent
Write-Host ("Coverage: {0:N2}% (target {1}%)" -f $coverage, $MinimumCoverage)

if ($result.FailedCount -gt 0) {
    Write-Host "ERROR: $($result.FailedCount) test(s) failed."
    exit 1
}
if ($coverage -lt $MinimumCoverage) {
    Write-Host ("ERROR: Coverage {0:N2}% is below the {1}% gate." -f $coverage, $MinimumCoverage)
    exit 1
}
exit 0
