@{
    RootModule        = 'TVSSave.Tools.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e8b4d6f2-3c5e-4a7d-9f1e-2c4b6a8d0f3e'
    Author            = 'Fealyx/TVS Contributors'
    CompanyName       = 'Fealyx'
    Copyright         = '(c) Fealyx/TVS Contributors. All rights reserved.'
    Description       = 'Cmdlets for inspecting, exporting, importing, and syncing character data in TVS save files.'
    PowerShellVersion = '7.0'
    RequiredModules   = @(
        @{ ModuleName = 'TVS.Environment'; ModuleVersion = '0.1.0' },
        @{ ModuleName = 'Znelchar.Tools'; ModuleVersion = '0.2.0' }
    )
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
