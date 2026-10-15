BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'DeployCommon helpers' {
    It 'Resolve-DeployPath returns an absolute path' {
        $input = Join-Path $TestDrive 'app'
        $resolved = & $script:module { param($p) Resolve-DeployPath -Path $p } $input
        [System.IO.Path]::IsPathRooted($resolved) | Should -BeTrue
        $resolved | Should -Be $input
    }

    It 'Get-DeployStateRoot defaults to <target>/.deploy' {
        $target = Join-Path $TestDrive 'app'
        $state = & $script:module { param($t) Get-DeployStateRoot -TargetPath $t } $target
        $state | Should -Be (Join-Path $target '.deploy')
    }

    It 'Get-DeployStateRoot honours -StateRoot override' {
        $target = Join-Path $TestDrive 'app'
        $custom = Join-Path $TestDrive 'state-elsewhere'
        $state = & $script:module { param($t, $s) Get-DeployStateRoot -TargetPath $t -StateRoot $s } $target $custom
        $state | Should -Be $custom
    }

    It 'Get-DeployTimestamp is sortable with milliseconds' {
        $stamp = & $script:module { Get-DeployTimestamp }
        $stamp | Should -Match '^\d{8}-\d{6}-\d{3}$'
    }

    It 'New-DeployError carries the stable code in brackets' {
        $err = & $script:module { New-DeployError -Code 'DEPLOY_PREREQ_FAILED' -Message 'disk full' }
        $err | Should -BeOfType ([System.InvalidOperationException])
        $err.Message | Should -Be '[DEPLOY_PREREQ_FAILED] disk full'
    }

    It 'New-DeployRecord builds a record with ISO invariant timestamp' {
        $rec = & $script:module { New-DeployRecord -TargetPath 'C:\app' -Status 'Succeeded' -DurationMs 42 }
        $rec.Id | Should -Match '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$'
        $rec.Timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$'
        $rec.Status | Should -Be 'Succeeded'
        $rec.DurationMs | Should -Be 42
        $rec.BackupPath | Should -BeNullOrEmpty
        $rec.Error | Should -BeNullOrEmpty
    }

    It 'New-DeployRecord rejects unknown status' {
        { & $script:module { New-DeployRecord -TargetPath 'C:\app' -Status 'Nope' } } | Should -Throw
    }
}
