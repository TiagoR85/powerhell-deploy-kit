# Shared test bootstrap. This file lives in <repo>\Tests, so its parent is the repo root.
$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'powerhell-deploy-kit.psd1') -Force
