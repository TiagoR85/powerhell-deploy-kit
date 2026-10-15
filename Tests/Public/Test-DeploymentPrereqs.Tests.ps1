BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
}

Describe 'Test-DeploymentPrereqs' {
    BeforeEach {
        $script:source = Join-Path $TestDrive 'src'
        New-Item -ItemType Directory -Path $script:source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:source 'app.txt') -Value 'payload'
        $script:target = Join-Path $TestDrive 'app'
        if (Test-Path -LiteralPath $script:target) {
            Remove-Item -LiteralPath $script:target -Recurse -Force
        }
    }

    It 'passes with a valid source and creatable target' {
        $result = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $script:target
        $result.Passed | Should -BeTrue
        @($result.Failures).Count | Should -Be 0
    }

    It 'fails when source does not exist' {
        $result = Test-DeploymentPrereqs -SourcePath (Join-Path $TestDrive 'missing') -TargetPath $script:target
        $result.Passed | Should -BeFalse
        (@($result.Failures) -join ';') | Should -Match 'Source not found'
    }

    It 'fails when target exists and is a file' {
        $fileTarget = Join-Path $TestDrive 'a-file.txt'
        Set-Content -LiteralPath $fileTarget -Value 'not a dir'
        $result = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $fileTarget
        $result.Passed | Should -BeFalse
        (@($result.Failures) -join ';') | Should -Match 'not a directory'
    }

    It 'fails when state location is not writable (mocked)' {
        Mock -ModuleName powerhell-deploy-kit Test-StateRootWritable { $false }
        $result = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $script:target
        $result.Passed | Should -BeFalse
        (@($result.Failures) -join ';') | Should -Match 'not writable'
    }

    It 'fails when free space is below the floor (mocked Get-PSDrive)' {
        Mock -ModuleName powerhell-deploy-kit Get-PSDrive {
            [pscustomobject]@{ Name = 'X'; Free = 1KB }
        }
        $result = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $script:target
        $result.Passed | Should -BeFalse
        (@($result.Failures) -join ';') | Should -Match 'Insufficient free space'
    }

    It 'fails when HealthUrl is unreachable (mocked Test-NetConnection)' {
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $false }
        $result = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $script:target `
            -HealthUrl 'http://health.invalid.test:9999/'
        $result.Passed | Should -BeFalse
        (@($result.Failures) -join ';') | Should -Match 'not reachable'
    }

    It 'passes when HealthUrl is reachable (mocked Test-NetConnection)' {
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $true }
        $result = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $script:target `
            -HealthUrl 'http://127.0.0.1:59999/'
        $result.Passed | Should -BeTrue
    }

    It 'never throws, even with every check failing' {
        Mock -ModuleName powerhell-deploy-kit Test-StateRootWritable { $false }
        Mock -ModuleName powerhell-deploy-kit Test-NetConnection { $false }
        $script:lastResult = $null
        {
            $script:lastResult = Test-DeploymentPrereqs -SourcePath (Join-Path $TestDrive 'nope') `
                -TargetPath $script:target -HealthUrl 'http://health.invalid.test/'
        } | Should -Not -Throw
        $script:lastResult.Passed | Should -BeFalse
        @($script:lastResult.Failures).Count | Should -BeGreaterOrEqual 3
    }

    It 'leaves no probe residue behind' {
        $null = Test-DeploymentPrereqs -SourcePath $script:source -TargetPath $script:target
        Test-Path -LiteralPath (Join-Path $script:target '.deploy') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $TestDrive '.deploy') | Should -BeFalse
    }
}
