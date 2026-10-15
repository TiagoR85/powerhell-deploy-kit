BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'Invoke-Rollback' {
    BeforeEach {
        foreach ($dir in @((Join-Path $TestDrive 'app'), (Join-Path $TestDrive 'backups'), (Join-Path $TestDrive 'no-such-app'))) {
            if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        }
        $script:target = Join-Path $TestDrive 'app'
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'current.txt') -Value 'v2'
        $script:state = Join-Path $script:target '.deploy'
        $script:backup = Join-Path $TestDrive 'backups\snap-1'
        New-Item -ItemType Directory -Path $script:backup -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:backup 'current.txt') -Value 'v1'
    }

    It 'restores target content from the explicit backup path' {
        Invoke-Rollback -TargetPath $script:target -BackupPath $script:backup
        Get-Content -LiteralPath (Join-Path $script:target 'current.txt') | Should -Be 'v1'
    }

    It 'appends a RolledBack history record' {
        Invoke-Rollback -TargetPath $script:target -BackupPath $script:backup
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].Status | Should -Be 'RolledBack'
        $history[0].BackupPath | Should -Be $script:backup
    }

    It 'throws TARGET_NOT_FOUND when the target does not exist' {
        $missing = Join-Path $TestDrive 'no-such-app'
        { Invoke-Rollback -TargetPath $missing -BackupPath $script:backup } |
            Should -Throw -ExpectedMessage '*TARGET_NOT_FOUND*'
    }

    It 'throws ROLLBACK_NOT_FOUND when the backup does not exist' {
        $missingBackup = Join-Path $TestDrive 'no-such-backup'
        { Invoke-Rollback -TargetPath $script:target -BackupPath $missingBackup } |
            Should -Throw -ExpectedMessage '*ROLLBACK_NOT_FOUND*'
        Get-Content -LiteralPath (Join-Path $script:target 'current.txt') | Should -Be 'v2'
    }

    It 'respects -WhatIf' {
        Invoke-Rollback -TargetPath $script:target -BackupPath $script:backup -WhatIf
        Get-Content -LiteralPath (Join-Path $script:target 'current.txt') | Should -Be 'v2'
        @(Get-DeployHistory -TargetPath $script:target).Count | Should -Be 0
    }
}
