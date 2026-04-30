function Get-TVSMVersion {
<#
.SYNOPSIS
Displays the current version of tvsm and its bundled components.

.PARAMETER Json
Emit version info as JSON to stdout.

.EXAMPLE
Get-TVSMVersion
tvsm version --json
#>
    [CmdletBinding()]
    param(
        [switch]$Json
    )

    $tvsmVersion = (Import-PowerShellDataFile (Join-Path $script:TVSMModuleRoot 'TVSM.psd1')).ModuleVersion

    $tvsEnvModule = Get-Module -ListAvailable -Name 'TVS.Environment' | Sort-Object Version -Descending | Select-Object -First 1
    $spectreModule = Get-Module -ListAvailable -Name 'PwshSpectreConsole' | Sort-Object Version -Descending | Select-Object -First 1

    $info = [ordered]@{
        tvsm                 = $tvsmVersion
        'TVS.Environment'    = if ($tvsEnvModule) { [string]$tvsEnvModule.Version } else { '(not found)' }
        PwshSpectreConsole   = if ($spectreModule) { [string]$spectreModule.Version } else { '(not found)' }
    }

    if ($Json) {
        $info | ConvertTo-Json -Depth 3
        return
    }

    $rows = $info.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{ Component = $_.Key; Version = $_.Value }
    }

    $rows | Format-SpectreTable -Border Rounded -Color Blue -Title '[cyan]tvsm component versions[/]'
}
