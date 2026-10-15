BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'Write-DeployHistory' {
    BeforeEach {
        $script:state = Join-Path $TestDrive 'state'
        if (Test-Path -LiteralPath $script:state) {
            Remove-Item -LiteralPath $script:state -Recurse -Force
        }
        $script:historyPath = Join-Path $script:state 'history.json'
    }

    It 'creates the state directory when missing' {
        $record = [pscustomobject]@{ Id = 'r1'; Status = 'Succeeded' }
        & $script:module { param($r, $p) Write-DeployHistory -Record $r -HistoryPath $p } $record $script:historyPath
        Test-Path -LiteralPath $script:historyPath | Should -BeTrue
    }

    It 'appends one compact JSON line per call' {
        foreach ($i in 1..2) {
            $record = [pscustomobject]@{ Id = "r$i"; Status = 'Succeeded' }
            & $script:module { param($r, $p) Write-DeployHistory -Record $r -HistoryPath $p } $record $script:historyPath
        }
        $lines = @(Get-Content -LiteralPath $script:historyPath)
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match '^\{"Id":"r1"'
        $lines[0].Length | Should -Be ($lines[0].Trim().Length)
    }

    It 'writes UTF-8 without BOM' {
        $record = [pscustomobject]@{ Id = 'r1'; Status = 'Succeeded' }
        & $script:module { param($r, $p) Write-DeployHistory -Record $r -HistoryPath $p } $record $script:historyPath
        $bytes = [System.IO.File]::ReadAllBytes($script:historyPath)
        $bytes[0] | Should -Not -Be 0xEF
    }
}
