BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
    function script:New-TargetWithV1 {
        param([string]$Root)
        $target = Join-Path $Root 'app'
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $target 'old.txt') -Value 'v1'
        $target
    }
    function script:New-SourceWithV2 {
        param([string]$Root)
        $source = Join-Path $Root 'src'
        if (Test-Path -LiteralPath $source) { Remove-Item -LiteralPath $source -Recurse -Force }
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'old.txt') -Value 'v2'
        Set-Content -LiteralPath (Join-Path $source 'extra.txt') -Value 'extra'
        $source
    }
}

Describe 'Invoke-Deploy' {
    BeforeEach {
        $script:target = New-TargetWithV1 -Root $TestDrive
        $script:source = New-SourceWithV2 -Root $TestDrive
    }

    It 'deploys a folder and records a Succeeded history entry' {
        Invoke-Deploy -SourcePath $script:source -TargetPath $script:target
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v2'
        Test-Path -LiteralPath (Join-Path $script:target 'extra.txt') | Should -BeTrue
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history.Count | Should -Be 1
        $history[0].Status | Should -Be 'Succeeded'
        $history[0].HealthChecked | Should -BeFalse
        $history[0].BackupPath | Should -Not -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath (Join-Path $script:target '.deploy\backups')).Count | Should -Be 1
    }

    It 'respects -WhatIf: no changes and no history' {
        Invoke-Deploy -SourcePath $script:source -TargetPath $script:target -WhatIf
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v1'
        @(Get-DeployHistory -TargetPath $script:target).Count | Should -Be 0
    }

    It 'throws DEPLOY_PREREQ_FAILED when source is missing and leaves target untouched' {
        $missing = Join-Path $TestDrive 'ghost'
        { Invoke-Deploy -SourcePath $missing -TargetPath $script:target } |
            Should -Throw -ExpectedMessage '*DEPLOY_PREREQ_FAILED*'
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v1'
        @(Get-DeployHistory -TargetPath $script:target).Count | Should -Be 0
    }

    It 'throws DEPLOY_PREREQ_FAILED when target is a file' {
        $fileTarget = Join-Path $TestDrive 'a-file.txt'
        Set-Content -LiteralPath $fileTarget -Value 'not a dir'
        { Invoke-Deploy -SourcePath $script:source -TargetPath $fileTarget } |
            Should -Throw -ExpectedMessage '*DEPLOY_PREREQ_FAILED*'
    }

    It 'marks HealthChecked=true on a healthy check' {
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $true }
        Mock -ModuleName powerhell-deploy-kit Invoke-HealthCheck { $true }
        Invoke-Deploy -SourcePath $script:source -TargetPath $script:target `
            -HealthUrl ([uri]'http://127.0.0.1:59999/ready') -HealthDelaySeconds 0
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].Status | Should -Be 'Succeeded'
        $history[0].HealthChecked | Should -BeTrue
    }

    It 'rolls back automatically when the health check fails' {
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $true }
        Mock -ModuleName powerhell-deploy-kit Invoke-HealthCheck { $false }
        { Invoke-Deploy -SourcePath $script:source -TargetPath $script:target `
            -HealthUrl ([uri]'http://127.0.0.1:59999/ready') -HealthDelaySeconds 0 } |
            Should -Throw -ExpectedMessage '*DEPLOY_HEALTH_FAILED*'
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v1'
        Test-Path -LiteralPath (Join-Path $script:target 'extra.txt') | Should -BeFalse
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].Status | Should -Be 'RolledBack'
        $history[0].Error | Should -Match 'DEPLOY_HEALTH_FAILED'
    }

    It 'rolls back when the artifact copy fails' {
        Mock -ModuleName powerhell-deploy-kit Copy-Artifact { throw 'copy exploded' }
        { Invoke-Deploy -SourcePath $script:source -TargetPath $script:target } |
            Should -Throw -ExpectedMessage '*copy exploded*'
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v1'
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].Status | Should -Be 'RolledBack'
        $history[0].Error | Should -Match 'copy exploded'
    }

    It 'records Failed and rethrows the original error when auto-rollback itself fails' {
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $true }
        Mock -ModuleName powerhell-deploy-kit Invoke-HealthCheck { $false }
        Mock -ModuleName powerhell-deploy-kit Restore-TargetBackup { throw 'restore exploded' }
        { Invoke-Deploy -SourcePath $script:source -TargetPath $script:target `
            -HealthUrl ([uri]'http://127.0.0.1:59999/ready') -HealthDelaySeconds 0 } |
            Should -Throw -ExpectedMessage '*DEPLOY_HEALTH_FAILED*'
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].Status | Should -Be 'Failed'
        $history[0].Error | Should -Match 'DEPLOY_HEALTH_FAILED'
    }

    It 'records round-trippable metadata (target path, duration, ISO timestamp)' {
        Invoke-Deploy -SourcePath $script:source -TargetPath $script:target
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].TargetPath | Should -Be $script:target
        $history[0].DurationMs | Should -BeGreaterOrEqual 0
        $history[0].Timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$'
    }

    It 'deploys from a .zip source' {
        $zip = Join-Path $TestDrive 'payload.zip'
        Compress-Archive -Path (Join-Path $script:source '*') -DestinationPath $zip -Force
        Invoke-Deploy -SourcePath $zip -TargetPath $script:target
        Get-Content -LiteralPath (Join-Path $script:target 'old.txt') | Should -Be 'v2'
        @(Get-DeployHistory -TargetPath $script:target)[0].Status | Should -Be 'Succeeded'
    }

    It 'fresh target + health failure: content stays, status Failed' {
        $fresh = Join-Path $TestDrive 'fresh-app'
        if (Test-Path -LiteralPath $fresh) { Remove-Item -LiteralPath $fresh -Recurse -Force }
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $true }
        Mock -ModuleName powerhell-deploy-kit Invoke-HealthCheck { $false }
        { Invoke-Deploy -SourcePath $script:source -TargetPath $fresh `
            -HealthUrl ([uri]'http://127.0.0.1:59999/ready') -HealthDelaySeconds 0 } |
            Should -Throw -ExpectedMessage '*DEPLOY_HEALTH_FAILED*'
        Test-Path -LiteralPath (Join-Path $fresh 'old.txt') | Should -BeTrue
        $history = @(Get-DeployHistory -TargetPath $fresh)
        $history[0].Status | Should -Be 'Failed'
        $history[0].BackupPath | Should -BeNullOrEmpty
    }
}
