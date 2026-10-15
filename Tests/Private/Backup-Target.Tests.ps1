BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'Backup-Target' {
    BeforeEach {
        $script:target = Join-Path $TestDrive 'app'
        $script:state = Join-Path $script:target '.deploy'
        if (Test-Path -LiteralPath $script:target) {
            Remove-Item -LiteralPath $script:target -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'old.txt') -Value 'v1'
        New-Item -ItemType Directory -Path (Join-Path $script:target 'sub') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'sub\nested.txt') -Value 'nested'
        New-Item -ItemType Directory -Path $script:state -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:state 'history.json') -Value 'prior-state'
    }

    It 'snapshots target content into state/backups/<stamp>' {
        $backupPath = & $script:module { param($t, $s) Backup-Target -TargetPath $t -StateRoot $s } $script:target $script:state
        $backupPath | Should -Not -BeNullOrEmpty
        (Split-Path -Parent $backupPath) | Should -Be (Join-Path $script:state 'backups')
        Get-Content -LiteralPath (Join-Path $backupPath 'old.txt') | Should -Be 'v1'
        Get-Content -LiteralPath (Join-Path $backupPath 'sub\nested.txt') | Should -Be 'nested'
    }

    It 'excludes the .deploy directory from the snapshot' {
        $backupPath = & $script:module { param($t, $s) Backup-Target -TargetPath $t -StateRoot $s } $script:target $script:state
        Test-Path -LiteralPath (Join-Path $backupPath '.deploy') | Should -BeFalse
    }

    It 'returns nothing when the target does not exist' {
        $missing = Join-Path $TestDrive 'no-such-app'
        $backupPath = & $script:module { param($t, $s) Backup-Target -TargetPath $t -StateRoot $s } $missing (Join-Path $missing '.deploy')
        $backupPath | Should -BeNullOrEmpty
    }

    It 'avoids stamp collisions with a suffix' {
        $b1 = & $script:module { param($t, $s) Backup-Target -TargetPath $t -StateRoot $s } $script:target $script:state
        $b2 = & $script:module { param($t, $s) Backup-Target -TargetPath $t -StateRoot $s } $script:target $script:state
        $b1 | Should -Not -Be $b2
        Test-Path -LiteralPath $b1 | Should -BeTrue
        Test-Path -LiteralPath $b2 | Should -BeTrue
    }
}

Describe 'Restore-TargetBackup' {
    BeforeEach {
        $script:target = Join-Path $TestDrive 'app'
        $script:state = Join-Path $script:target '.deploy'
        if (Test-Path -LiteralPath $script:target) {
            Remove-Item -LiteralPath $script:target -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'old.txt') -Value 'v1'
        New-Item -ItemType Directory -Path $script:state -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:state 'history.json') -Value 'state-data'
        $script:backup = & $script:module { param($t, $s) Backup-Target -TargetPath $t -StateRoot $s } $script:target $script:state
        Set-Content -LiteralPath (Join-Path $script:target 'old.txt') -Value 'v2'
        Set-Content -LiteralPath (Join-Path $script:target 'new.txt') -Value 'added'
    }

    It 'restores the snapshot and removes post-backup content' {
        & $script:module { param($b, $t) Restore-TargetBackup -BackupPath $b -TargetPath $t } $script:backup $script:target
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v1'
        Test-Path -LiteralPath (Join-Path $script:target 'new.txt') | Should -BeFalse
    }

    It 'keeps the .deploy state directory intact' {
        & $script:module { param($b, $t) Restore-TargetBackup -BackupPath $b -TargetPath $t } $script:backup $script:target
        Test-Path -LiteralPath (Join-Path $script:state 'history.json') | Should -BeTrue
    }

    It 'throws ROLLBACK_NOT_FOUND for a missing backup' {
        $missing = Join-Path $TestDrive 'no-such-backup'
        {
            & $script:module { param($b, $t) Restore-TargetBackup -BackupPath $b -TargetPath $t } $missing $script:target
        } | Should -Throw -ExpectedMessage '*ROLLBACK_NOT_FOUND*'
    }
}
