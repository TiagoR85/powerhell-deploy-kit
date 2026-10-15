BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
    function script:New-HistoryRecord {
        param([string]$Id, [string]$Status = 'Succeeded', [string]$BackupPath = '')
        [pscustomobject]@{
            Id            = $Id
            Timestamp     = '2026-10-15T10:00:00.000'
            TargetPath    = 'C:\app'
            Status        = $Status
            BackupPath    = $BackupPath
            HealthChecked = $true
            DurationMs    = 7
            Error         = ''
        }
    }
}

Describe 'Get-DeployHistory' {
    BeforeEach {
        $script:target = Join-Path $TestDrive 'app'
        if (Test-Path -LiteralPath $script:target) {
            Remove-Item -LiteralPath $script:target -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        $script:state = Join-Path $script:target '.deploy'
        $script:historyPath = Join-Path $script:state 'history.json'
    }

    Context 'when history file is missing' {
        It 'returns an empty array' {
            $result = @(Get-DeployHistory -TargetPath $script:target)
            $result.Count | Should -Be 0
        }
    }

    Context 'with three records' {
        BeforeEach {
            foreach ($id in 'rec-1', 'rec-2', 'rec-3') {
                $record = New-HistoryRecord -Id $id
                & $script:module { param($r, $p) Write-DeployHistory -Record $r -HistoryPath $p } $record $script:historyPath
            }
        }

        It 'returns records newest first' {
            $result = @(Get-DeployHistory -TargetPath $script:target)
            $result.Count | Should -Be 3
            $result[0].Id | Should -Be 'rec-3'
            $result[2].Id | Should -Be 'rec-1'
        }

        It 'honours -Last N' {
            $result = @(Get-DeployHistory -TargetPath $script:target -Last 2)
            $result.Count | Should -Be 2
            $result[0].Id | Should -Be 'rec-3'
            $result[1].Id | Should -Be 'rec-2'
        }

        It 'round-trips record fields' {
            $result = @(Get-DeployHistory -TargetPath $script:target)
            $result[0].Status | Should -Be 'Succeeded'
            $result[0].HealthChecked | Should -BeTrue
            $result[0].DurationMs | Should -Be 7
        }

        It 'skips blank lines' {
            Add-Content -LiteralPath $script:historyPath -Value ''
            $result = @(Get-DeployHistory -TargetPath $script:target)
            $result.Count | Should -Be 3
        }

        It 'reads history from an external -StateRoot' {
            $extState = Join-Path $TestDrive 'external-state'
            $extHistory = Join-Path $extState 'history.json'
            $record = New-HistoryRecord -Id 'ext-1'
            & $script:module { param($r, $p) Write-DeployHistory -Record $r -HistoryPath $p } $record $extHistory
            $result = @(Get-DeployHistory -TargetPath $script:target -StateRoot $extState)
            $result.Count | Should -Be 1
            $result[0].Id | Should -Be 'ext-1'
        }
    }

    Context 'when history is corrupt' {
        It 'throws HISTORY_CORRUPT' {
            New-Item -ItemType Directory -Path $script:state -Force | Out-Null
            Set-Content -LiteralPath $script:historyPath -Value '{"Id":"ok"}'
            Add-Content -LiteralPath $script:historyPath -Value 'this is not json'
            { Get-DeployHistory -TargetPath $script:target } |
                Should -Throw -ExpectedMessage '*HISTORY_CORRUPT*'
        }
    }
}
