function Convert-ZnelcharToYaml {
<#
.SYNOPSIS
Dumps a .znelchar file to a YAML representation without texture payloads.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [string]$OutputPath,
        [switch]$MetadataOnly
    )

    $resolvedInputPath = (Resolve-Path $InputPath).Path
    if (-not $OutputPath) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputPath)
        $OutputPath = Join-Path ([System.IO.Path]::GetDirectoryName($resolvedInputPath)) ($base + '.yaml')
    }
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)

    if (-not $PSCmdlet.ShouldProcess($resolvedOutputPath, 'Write YAML dump')) {
        return
    }

    Write-Stage -Prefix 'dump-yaml' -Message "Loading $resolvedInputPath"
    $outer = Read-JsonFile -Path $resolvedInputPath
    $character = $null
    if ($outer.ContainsKey('_characterData') -and -not $MetadataOnly) {
        Write-Stage -Prefix 'dump-yaml' -Message 'Parsing _characterData'
        $character = ($outer['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100)
        $character = Expand-NestedCharacterData -Character $character -WarnOnFailure
    }

    $textures = @()
    if ($outer.ContainsKey('_textureDatas') -and $null -ne $outer['_textureDatas']) {
        $textures = @($outer['_textureDatas'])
    }

    $textureSummary = @()
    foreach ($t in $textures) {
        $name = if ($t.ContainsKey('_textureName')) { [string]$t['_textureName'] } else { '<missing>' }
        $b64 = if ($t.ContainsKey('_textureData') -and $null -ne $t['_textureData']) { [string]$t['_textureData'] } else { '' }
        $textureSummary += [ordered]@{
            textureName = $name
            base64Length = [int64]$b64.Length
            estimatedDecodedBytes = [int64][Math]::Floor(($b64.Length * 3) / 4)
        }
    }

    $clean = [ordered]@{
        sourceFile = $resolvedInputPath
        topLevelKeys = @($outer.Keys | Sort-Object)
        textureCount = $textureSummary.Count
        textureSummary = $textureSummary
        characterData = $character
    }

    if (-not (Get-Command ConvertTo-Yaml -ErrorAction SilentlyContinue)) {
        throw 'ConvertTo-Yaml was not found. Install module: Install-Module powershell-yaml -Scope CurrentUser'
    }

    Write-Stage -Prefix 'dump-yaml' -Message 'Rendering YAML'
    $yaml = $clean | ConvertTo-Yaml -Options UseFlowStyle,WithIndentedSequences
    Write-Utf8NoBomFile -Path $resolvedOutputPath -Content $yaml

    Write-Stage -Prefix 'dump-yaml' -Message 'Completed'
    return [ordered]@{
        outputFile = $resolvedOutputPath
        textureCount = $textureSummary.Count
    }
}
