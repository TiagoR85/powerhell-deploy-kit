BeforeAll {
    . (Join-Path $PSScriptRoot '_Import.ps1')
    $manifestPath = Join-Path $repoRoot 'powerhell-deploy-kit.psd1'
}

Describe 'Module scaffold' {
    It 'manifest is a valid module manifest' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'declares PowerShellVersion 5.1' {
        (Test-ModuleManifest -Path $manifestPath).PowerShellVersion | Should -Be ([version]'5.1')
    }

    It 'exports exactly the 5 public functions' {
        $exported = @((Get-Command -Module powerhell-deploy-kit).Name)
        $exported.Count | Should -Be 5
        foreach ($name in @('Invoke-Deploy', 'Invoke-Rollback', 'Undo-LastDeployment', 'Test-DeploymentPrereqs', 'Get-DeployHistory')) {
            $exported | Should -Contain $name
        }
    }

    It 'does not leak private helpers' {
        $exported = @((Get-Command -Module powerhell-deploy-kit).Name)
        $exported | Should -Not -Contain 'New-DeployError'
        $exported | Should -Not -Contain 'Write-DeployHistory'
    }
}
