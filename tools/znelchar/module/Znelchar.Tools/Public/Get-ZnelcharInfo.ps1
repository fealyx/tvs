function Get-ZnelcharInfo {
<#
.SYNOPSIS
Inspects a .znelchar file and returns structured metadata.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [string]$OuterSchemaPath,
        [string]$CharacterSchemaPath,
        [string]$OpinionDataSchemaPath,
        [switch]$ValidateSchema,
        [switch]$MetadataOnly
    )

    $toolRoot = Get-ZnelcharToolRoot
    if (-not $OuterSchemaPath) { $OuterSchemaPath = Join-Path $toolRoot 'schemas/znelchar.schema.json' }
    if (-not $CharacterSchemaPath) { $CharacterSchemaPath = Join-Path $toolRoot 'schemas/characterData.schema.json' }
    if (-not $OpinionDataSchemaPath) { $OpinionDataSchemaPath = Join-Path $toolRoot 'schemas/opinionDataString.schema.json' }

    $resolvedInputPath = (Resolve-Path $InputPath).Path
    if (-not $PSCmdlet.ShouldProcess($resolvedInputPath, 'Inspect .znelchar file')) {
        return
    }

    Write-Stage -Prefix 'inspect' -Message "Loading $resolvedInputPath"
    $outer = Read-JsonFile -Path $resolvedInputPath
    $topLevelKeys = @($outer.Keys | Sort-Object)
    $knownTopLevelKeys = @('_characterData', '_textureDatas')
    $unknownTopLevelKeys = @($topLevelKeys | Where-Object { $_ -notin $knownTopLevelKeys })

    if (-not $outer.ContainsKey('_characterData')) { throw 'Missing required key: _characterData' }
    if ($outer['_characterData'] -isnot [string]) { throw '_characterData must be a string' }

    $character = $null
    $characterParseError = $null
    if (-not $MetadataOnly) {
        try {
            Write-Stage -Prefix 'inspect' -Message 'Parsing _characterData'
            $character = ($outer['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100)
        }
        catch {
            $characterParseError = $_.Exception.Message
        }
    }

    $opinionData = $null
    $opinionDataParseError = $null
    if ($null -ne $character -and $character.ContainsKey('opinionDataString') -and $character['opinionDataString'] -is [string]) {
        try {
            $opinionData = ($character['opinionDataString'] | ConvertFrom-Json -AsHashtable -Depth 100)
        }
        catch {
            $opinionDataParseError = $_.Exception.Message
        }
    }

    $textures = @()
    if ($outer.ContainsKey('_textureDatas') -and $null -ne $outer['_textureDatas']) {
        $textures = @($outer['_textureDatas'])
    }
    Write-Stage -Prefix 'inspect' -Message "Found $($textures.Count) texture entries"

    $textureSummary = @()
    $totalBase64Length = 0L
    foreach ($t in $textures) {
        $name = if ($t.ContainsKey('_textureName')) { [string]$t['_textureName'] } else { '<missing>' }
        $b64 = if ($t.ContainsKey('_textureData') -and $null -ne $t['_textureData']) { [string]$t['_textureData'] } else { '' }
        $len = [int64]$b64.Length
        $totalBase64Length += $len
        $textureSummary += [ordered]@{
            textureName = $name
            base64Length = $len
            estimatedDecodedBytes = [int64][Math]::Floor(($len * 3) / 4)
        }
    }

    $schemaValidation = [ordered]@{
        attempted = [bool]$ValidateSchema
        outerValid = $null
        characterValid = $null
        opinionDataValid = $null
        notes = @()
    }

    if ($ValidateSchema) {
        if (Get-Command Test-Json -ErrorAction SilentlyContinue) {
            if (Test-Path $OuterSchemaPath) {
                $outerJson = $outer | ConvertTo-Json -Depth 100
                $schemaValidation.outerValid = [bool]($outerJson | Test-Json -SchemaFile (Resolve-Path $OuterSchemaPath))
            }
            else {
                $schemaValidation.notes += "Outer schema not found: $OuterSchemaPath"
            }

            if ($null -ne $character -and (Test-Path $CharacterSchemaPath)) {
                $characterJson = $character | ConvertTo-Json -Depth 100
                $schemaValidation.characterValid = [bool]($characterJson | Test-Json -SchemaFile (Resolve-Path $CharacterSchemaPath))
            }
            elseif ($null -eq $character) {
                $schemaValidation.notes += 'Skipped character schema validation because _characterData did not parse'
            }
            else {
                $schemaValidation.notes += "Character schema not found: $CharacterSchemaPath"
            }

            if ($null -ne $opinionData -and (Test-Path $OpinionDataSchemaPath)) {
                $opinionDataJson = $opinionData | ConvertTo-Json -Depth 100
                $schemaValidation.opinionDataValid = [bool]($opinionDataJson | Test-Json -SchemaFile (Resolve-Path $OpinionDataSchemaPath))
            }
            elseif ($null -ne $character -and $character.ContainsKey('opinionDataString') -and $null -eq $opinionData) {
                $schemaValidation.notes += 'Skipped opinionDataString schema validation because nested JSON did not parse'
            }
            elseif ($null -ne $character -and $character.ContainsKey('opinionDataString')) {
                $schemaValidation.notes += "Opinion data schema not found: $OpinionDataSchemaPath"
            }
        }
        else {
            $schemaValidation.notes += 'Test-Json is not available in this PowerShell host'
        }
    }

    Write-Stage -Prefix 'inspect' -Message 'Completed'
    return [ordered]@{
        file = $resolvedInputPath
        topLevelKeys = $topLevelKeys
        unknownTopLevelKeys = $unknownTopLevelKeys
        metadataOnly = [bool]$MetadataOnly
        characterDataParseSucceeded = if ($MetadataOnly) { $null } else { ($null -ne $character) }
        characterDataParseError = if ($MetadataOnly) { $null } else { $characterParseError }
        opinionDataParseSucceeded = if ($MetadataOnly) { $null } else { ($null -ne $opinionData) }
        opinionDataParseError = if ($MetadataOnly) { $null } else { $opinionDataParseError }
        textureCount = $textures.Count
        totalTextureBase64Length = $totalBase64Length
        textureEntries = if ($MetadataOnly) { @() } else { $textureSummary }
        schemaValidation = $schemaValidation
    }
}
