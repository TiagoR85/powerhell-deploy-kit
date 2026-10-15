BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'Test-Prereqs internals' {
    It 'Get-SourceSize sums a folder recursively' {
        $folder = Join-Path $TestDrive 'pkg'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $folder 'sub') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $folder 'a.txt') -Value ('x' * 100)
        Set-Content -LiteralPath (Join-Path $folder 'sub\b.txt') -Value ('y' * 50)
        $size = & $script:module { param($p) Get-SourceSize -Path $p } $folder
        $size | Should -BeGreaterOrEqual 150
    }

    It 'Get-SourceSize returns file length for a file' {
        $file = Join-Path $TestDrive 'one.zip'
        Set-Content -LiteralPath $file -Value ('z' * 10)
        $size = & $script:module { param($p) Get-SourceSize -Path $p } $file
        $size | Should -BeGreaterOrEqual 10
    }

    It 'Get-NearestExistingPath walks up to the first existing directory' {
        $missing = Join-Path $TestDrive 'a\b\c'
        $nearest = & $script:module { param($p) Get-NearestExistingPath -Path $p } $missing
        $nearest | Should -Be $TestDrive
    }

    It 'Test-StateRootWritable creates the .deploy shape and cleans up' {
        $state = Join-Path $TestDrive 'app\.deploy'
        $ok = & $script:module { param($s) Test-StateRootWritable -StateRootPath $s } $state
        $ok | Should -BeTrue
        Test-Path -LiteralPath $state | Should -BeFalse
    }

    It 'Test-StateRootWritable probes an existing state root in place' {
        $state = Join-Path $TestDrive 'app\.deploy'
        New-Item -ItemType Directory -Path $state -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $state 'keep.txt') -Value 'keep'
        $ok = & $script:module { param($s) Test-StateRootWritable -StateRootPath $s } $state
        $ok | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $state 'keep.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $state '.probe') | Should -BeFalse
    }
}
