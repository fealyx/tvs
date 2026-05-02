@{
    RootModule        = 'TVSM.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a7c3e5f1-2b4d-4a6c-8e0f-1d3b5a7c9e2f'
    Author            = 'Fealyx/TVS Contributors'
    CompanyName       = 'Fealyx'
    Copyright         = '(c) Fealyx/TVS Contributors. All rights reserved.'
    Description       = 'TVS Manager — unified CLI for end-users, mod developers, and content creators.'
    PowerShellVersion = '7.0'
    RequiredModules   = @(
        @{ ModuleName = 'TVS.Environment'; ModuleVersion = '0.1.0' },
        @{ ModuleName = 'PwshSpectreConsole'; ModuleVersion = '0.1.0' }
    )
    FunctionsToExport = @(
        # config
        'Show-TVSMConfig',
        'Invoke-TVSMConfigInit',
        # mod — core
        'Invoke-TVSMModApply',
        'Get-TVSMModStatus',
        'Install-TVSMMod',
        'Update-TVSMMod',
        'Remove-TVSMMod',
        'Invoke-TVSMModRollback',
        'Test-TVSMModEnvironment',
        'New-TVSMModSnapshot',
        # mod — profiles
        'Get-TVSMModProfileList',
        'Switch-TVSMModProfile',
        'New-TVSMModProfile',
        # mod — store
        'Get-TVSMModStoreList',
        'Invoke-TVSMModStorePrune',
        # mod — dev links
        'Add-TVSMDevLink',
        'Remove-TVSMDevLink',
        'Get-TVSMDevLinkList',
        # save
        'Get-TVSSaveList',
        'Export-TVSSavePreset',
        'Import-TVSSavePreset',
        'Expand-TVSSavePreset',
        'Watch-TVSSave',
        # version / self
        'Get-TVSMVersion'
    )
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('tvsm', 'tvs', 'powershell', 'tooling')
            ProjectUri = 'https://github.com/fealyx/tvs'
        }
    }
}
