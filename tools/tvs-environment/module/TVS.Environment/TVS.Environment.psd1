@{
    RootModule        = 'TVS.Environment.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'f3d1c2b4-5e6a-4f7b-9c0d-1e2f3a4b5c6d'
    Author            = 'Fealyx/TVS Contributors'
    CompanyName       = 'Fealyx'
    Copyright         = '(c) Fealyx/TVS Contributors. All rights reserved.'
    Description       = 'Shared environment profile module for TVS tooling. Provides a single source of truth for game directory, player data path, and other tool configuration.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-TVSEnvironment',
        'Set-TVSEnvironmentValue',
        'Initialize-TVSEnvironment',
        'Test-TVSEnvironment'
    )
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('tvs', 'environment', 'powershell', 'tooling')
            ProjectUri = 'https://github.com/fealyx/tvs'
        }
    }
}
