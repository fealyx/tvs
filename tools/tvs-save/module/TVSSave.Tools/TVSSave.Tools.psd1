@{
    RootModule        = 'TVSSave.Tools.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = 'e8b4d6f2-3c5e-4a7d-9f1e-2c4b6a8d0f3e'
    Author            = 'Fealyx/TVS Contributors'
    CompanyName       = 'Fealyx'
    Copyright         = '(c) Fealyx/TVS Contributors. All rights reserved.'
    Description       = 'Cmdlets for inspecting, exporting, importing, and syncing character data in TVS save files.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'ConvertFrom-TVSPresetSlot',
        'ConvertTo-TVSPresetSlot',
        'Get-TVSSaveCharacterList',
        'Export-TVSCharacterPreset',
        'Export-TVSAllCharacterPresets',
        'Import-TVSCharacterPreset',
        'Expand-TVSCharacterPreset',
        'Compress-TVSCharacterPreset',
        'Watch-TVSCharacterSync',
        'Stop-TVSCharacterSync',
        'Sync-TVSCharacterWorkDir',
        'Write-TVSCharacterSyncLog',
        'Get-TVSCharacterState',
        'Test-TVSCharacterSlotOccupied',
        'Get-TVSCharacterName',
        'Test-TVSValidPresetFile',
        'Remove-TVSCharacterPresetDirectory',
        'Invoke-TVSCharacterSync',
        'New-TVSCharacterWatcher',
        'Start-TVSCharacterProcessingLoop',
        'Invoke-TVSCharacterInitialSync'
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
