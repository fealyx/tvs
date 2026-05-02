@{
    RootModule        = 'TVSSave.Tools.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e8b4d6f2-3c5e-4a7d-9f1e-2c4b6a8d0f3e'
    Author            = 'Fealyx/TVS Contributors'
    CompanyName       = 'Fealyx'
    Copyright         = '(c) Fealyx/TVS Contributors. All rights reserved.'
    Description       = 'Cmdlets for inspecting, exporting, importing, and syncing character data in TVS save files.'
    PowerShellVersion = '7.0'
    # RequiredModules removed: dependency resolution is handled in .psm1
    # to support workspace development scenarios where modules are not in PSModulePath
    FunctionsToExport = @(
        'Get-TVSSaveCharacterList',
        'Export-TVSCharacterPreset',
        'Export-TVSAllCharacterPresets',
        'Import-TVSCharacterPreset',
        'Expand-TVSCharacterPreset',
        'Compress-TVSCharacterPreset',
        'Watch-TVSCharacterSync',
        'Stop-TVSCharacterSync'
    )
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('tvs', 'save', 'powershell', 'tooling', 'znelchar')
            ProjectUri = 'https://github.com/fealyx/tvs'
        }
    }
}
