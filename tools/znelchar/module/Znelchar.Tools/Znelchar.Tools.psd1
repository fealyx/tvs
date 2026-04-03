@{
    RootModule = 'Znelchar.Tools.psm1'
    ModuleVersion = '0.1.0'
    GUID = '2d9fd4f8-4e1f-4e4f-9ef5-2f5c07d4db92'
    Author = 'TVS'
    CompanyName = 'TVS'
    Copyright = '(c) TVS. All rights reserved.'
    Description = 'Cmdlet wrappers for working with .znelchar files.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-ZnelcharInfo',
        'Export-ZnelcharContent',
        'New-ZnelcharFile',
        'Convert-ZnelcharToYaml',
        'Test-ZnelcharFile',
        'Test-ZnelcharRoundtrip'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('znelchar', 'powershell', 'tooling')
            ProjectUri = 'https://example.invalid/tvs/znelchar'
        }
    }
}
