BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'Copy-Artifact' {
    BeforeEach {
        $script:source = Join-Path $TestDrive 'pkg'
        $script:target = Join-Path $TestDrive 'app'
        $script:state = Join-Path $script:target '.deploy'
        foreach ($dir in @($script:source, $script:target)) {
            if (Test-Path -LiteralPath $dir) {
                Remove-Item -LiteralPath $dir -Recurse -Force
            }
        }
        New-Item -ItemType Directory -Path $script:source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:source 'app.txt') -Value 'v2'
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'app.txt') -Value 'v1'
        Set-Content -LiteralPath (Join-Path $script:target 'stale.txt') -Value 'stale'
        New-Item -ItemType Directory -Path $script:state -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:state 'history.json') -Value '[]'
    }

    It 'replaces target content with the source folder' {
        & $script:module { param($s, $t, $st) Copy-Artifact -SourcePath $s -TargetPath $t -StateRoot $st } $script:source $script:target $script:state
        Get-Content -LiteralPath (Join-Path $script:target 'app.txt') | Should -Be 'v2'
        Test-Path -LiteralPath (Join-Path $script:target 'stale.txt') | Should -BeFalse
    }

    It 'preserves the .deploy state directory during the swap' {
        & $script:module { param($s, $t, $st) Copy-Artifact -SourcePath $s -TargetPath $t -StateRoot $st } $script:source $script:target $script:state
        Test-Path -LiteralPath (Join-Path $script:state 'history.json') | Should -BeTrue
    }

    It 'extracts a .zip through staging' {
        $zip = Join-Path $TestDrive 'pkg.zip'
        Compress-Archive -Path (Join-Path $script:source '*') -DestinationPath $zip -Force
        & $script:module { param($s, $t, $st) Copy-Artifact -SourcePath $s -TargetPath $t -StateRoot $st } $zip $script:target $script:state
        Get-Content -LiteralPath (Join-Path $script:target 'app.txt') | Should -Be 'v2'
        Test-Path -LiteralPath (Join-Path $script:state 'staging\app.txt') | Should -BeTrue
    }

    It 'creates the target when it does not exist' {
        $fresh = Join-Path $TestDrive 'fresh-app'
        if (Test-Path -LiteralPath $fresh) { Remove-Item -LiteralPath $fresh -Recurse -Force }
        & $script:module { param($s, $t, $st) Copy-Artifact -SourcePath $s -TargetPath $t -StateRoot $st } $script:source $fresh $script:state
        Test-Path -LiteralPath (Join-Path $fresh 'app.txt') | Should -BeTrue
    }

    It 'throws DEPLOY_SOURCE_INVALID when source is missing' {
        $missing = Join-Path $TestDrive 'ghost'
        {
            & $script:module { param($s, $t, $st) Copy-Artifact -SourcePath $s -TargetPath $t -StateRoot $st } $missing $script:target $script:state
        } | Should -Throw -ExpectedMessage '*DEPLOY_SOURCE_INVALID*'
    }

    It 'throws DEPLOY_SOURCE_INVALID for a non-zip file source' {
        $notZip = Join-Path $TestDrive 'payload.txt'
        Set-Content -LiteralPath $notZip -Value 'data'
        {
            & $script:module { param($s, $t, $st) Copy-Artifact -SourcePath $s -TargetPath $t -StateRoot $st } $notZip $script:target $script:state
        } | Should -Throw -ExpectedMessage '*DEPLOY_SOURCE_INVALID*'
    }
}
