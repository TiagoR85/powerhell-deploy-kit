BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
    function script:New-Source {
        param([string]$Root, [string]$Name, [string]$Content)
        $source = Join-Path $Root $Name
        if (Test-Path -LiteralPath $source) { Remove-Item -LiteralPath $source -Recurse -Force }
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'app.txt') -Value $Content
        $source
    }
}

Describe 'Undo-LastDeployment' {
    BeforeEach {
        foreach ($dir in @((Join-Path $TestDrive 'app'), (Join-Path $TestDrive 'no-such-app'))) {
            if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        }
        $script:target = Join-Path $TestDrive 'app'
        $script:src1 = New-Source -Root $TestDrive -Name 'src1' -Content 'v1'
        $script:src2 = New-Source -Root $TestDrive -Name 'src2' -Content 'v2'
    }

    It 'restores the backup of the newest Succeeded record' {
        Invoke-Deploy -SourcePath $script:src1 -TargetPath $script:target
        Invoke-Deploy -SourcePath $script:src2 -TargetPath $script:target
        Undo-LastDeployment -TargetPath $script:target
        Get-Content -LiteralPath (Join-Path $script:target 'app.txt') | Should -Be 'v1'
        $history = @(Get-DeployHistory -TargetPath $script:target)
        $history[0].Status | Should -Be 'RolledBack'
    }

    It 'throws ROLLBACK_NOT_FOUND when history has no suitable record' {
        Invoke-Deploy -SourcePath $script:src1 -TargetPath $script:target
        { Undo-LastDeployment -TargetPath $script:target } |
            Should -Throw -ExpectedMessage '*ROLLBACK_NOT_FOUND*'
    }

    It 'throws ROLLBACK_NOT_FOUND when there is no history at all' {
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        { Undo-LastDeployment -TargetPath $script:target } |
            Should -Throw -ExpectedMessage '*ROLLBACK_NOT_FOUND*'
    }

    It 'throws TARGET_NOT_FOUND when the target does not exist' {
        $missing = Join-Path $TestDrive 'no-such-app'
        { Undo-LastDeployment -TargetPath $missing } |
            Should -Throw -ExpectedMessage '*TARGET_NOT_FOUND*'
    }
}
