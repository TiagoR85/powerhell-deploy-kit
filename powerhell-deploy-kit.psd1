@{
    RootModule        = 'powerhell-deploy-kit.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b3e7d2f1-9c4a-4e8b-a6d5-1f0c9e2a7b34'
    Author            = 'TiagoR85'
    CompanyName       = 'TiagoR85'
    Copyright         = '(c) 2026 TiagoR85. Licensed under MIT.'
    Description       = 'Deploy kit for folder or .zip artifacts with backup, HTTP health check, automatic rollback, prerequisite checks and JSON Lines deploy history. Works on PowerShell 5.1 and 7.x.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Invoke-Deploy', 'Invoke-Rollback', 'Undo-LastDeployment', 'Test-DeploymentPrereqs', 'Get-DeployHistory')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Deploy', 'Rollback', 'HealthCheck', 'DevOps', 'Pester')
            LicenseUri = 'https://github.com/TiagoR85/powerhell-deploy-kit/blob/main/LICENSE'
            ProjectUri = 'https://github.com/TiagoR85/powerhell-deploy-kit'
        }
    }
}
