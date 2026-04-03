function Test-ZnelcharFile {
<#
.SYNOPSIS
Performs semantic equivalence verification between two .znelchar files.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$LeftPath,
        [Parameter(Mandatory = $true)][string]$RightPath,
        [switch]$IgnoreTextureOrder = $true,
        [string]$DiffReportPath,
        [switch]$CiSummary
    )

    $resolvedLeftPath = (Resolve-Path $LeftPath).Path
    $resolvedRightPath = (Resolve-Path $RightPath).Path
    $target = "$resolvedLeftPath <-> $resolvedRightPath"
    if (-not $PSCmdlet.ShouldProcess($target, 'Verify semantic equality')) {
        return
    }

    Write-Stage -Prefix 'verify' -Message 'Loading files'
    $leftOuter = Read-JsonFile -Path $resolvedLeftPath
    $rightOuter = Read-JsonFile -Path $resolvedRightPath

    $differences = @()

    Write-Stage -Prefix 'verify' -Message 'Comparing top-level keys'
    $leftKeys = @($leftOuter.Keys | Sort-Object)
    $rightKeys = @($rightOuter.Keys | Sort-Object)
    $topLevelDiff = [ordered]@{
        equal = (($leftKeys -join "`n") -eq ($rightKeys -join "`n"))
        leftOnly = @($leftKeys | Where-Object { $_ -notin $rightKeys })
        rightOnly = @($rightKeys | Where-Object { $_ -notin $leftKeys })
    }
    if (-not $topLevelDiff.equal) { $differences += 'Top-level keys differ' }

    Write-Stage -Prefix 'verify' -Message 'Comparing non-texture top-level values'
    $leftMeta = @{}
    $rightMeta = @{}
    foreach ($k in $leftOuter.Keys) {
        if ($k -notin @('_characterData', '_textureDatas')) { $leftMeta[$k] = $leftOuter[$k] }
    }
    foreach ($k in $rightOuter.Keys) {
        if ($k -notin @('_characterData', '_textureDatas')) { $rightMeta[$k] = $rightOuter[$k] }
    }
    $leftMetaJson = (Normalize-ForJson -Value $leftMeta) | ConvertTo-Json -Compress -Depth 100
    $rightMetaJson = (Normalize-ForJson -Value $rightMeta) | ConvertTo-Json -Compress -Depth 100
    $metaDiff = [ordered]@{
        equal = ($leftMetaJson -eq $rightMetaJson)
        leftJson = $leftMetaJson
        rightJson = $rightMetaJson
    }
    if (-not $metaDiff.equal) { $differences += 'Non-character/non-texture top-level payload differs' }

    Write-Stage -Prefix 'verify' -Message 'Comparing _characterData payload'
    if (-not $leftOuter.ContainsKey('_characterData') -or -not $rightOuter.ContainsKey('_characterData')) {
        $differences += 'One or both files are missing _characterData'
        $characterDiff = [ordered]@{
            equal = $false
            missingInLeft = (-not $leftOuter.ContainsKey('_characterData'))
            missingInRight = (-not $rightOuter.ContainsKey('_characterData'))
            leftJson = $null
            rightJson = $null
        }
    }
    else {
        $leftCharacter = Expand-NestedCharacterData -Character (($leftOuter['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100))
        $rightCharacter = Expand-NestedCharacterData -Character (($rightOuter['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100))

        $leftCharacterJson = (Normalize-ForJson -Value $leftCharacter) | ConvertTo-Json -Compress -Depth 100
        $rightCharacterJson = (Normalize-ForJson -Value $rightCharacter) | ConvertTo-Json -Compress -Depth 100
        $characterDiff = [ordered]@{
            equal = ($leftCharacterJson -eq $rightCharacterJson)
            missingInLeft = $false
            missingInRight = $false
            leftJson = $leftCharacterJson
            rightJson = $rightCharacterJson
        }
        if (-not $characterDiff.equal) { $differences += '_characterData semantic payload differs' }
    }

    Write-Stage -Prefix 'verify' -Message 'Comparing texture data'
    $leftTextureMap = Get-TextureMap -Outer $leftOuter
    $rightTextureMap = Get-TextureMap -Outer $rightOuter

    $leftTextureNames = @($leftTextureMap.Keys | Sort-Object)
    $rightTextureNames = @($rightTextureMap.Keys | Sort-Object)
    $textureDiffs = @()
    $leftOnlyTextures = @($leftTextureNames | Where-Object { $_ -notin $rightTextureNames })
    $rightOnlyTextures = @($rightTextureNames | Where-Object { $_ -notin $leftTextureNames })

    $sharedTextureNames = @($leftTextureNames | Where-Object { $_ -in $rightTextureNames })
    foreach ($name in $sharedTextureNames) {
        $leftDigest = $leftTextureMap[$name]
        $rightDigest = $rightTextureMap[$name]

        $contentEqual = ($leftDigest.sha256 -eq $rightDigest.sha256)
        $sizeEqual = ($leftDigest.decodedBytes -eq $rightDigest.decodedBytes)

        if (-not $contentEqual) { $differences += "Texture content differs for '$name'" }
        if (-not $sizeEqual) { $differences += "Texture decoded size differs for '$name'" }

        if ((-not $contentEqual) -or (-not $sizeEqual)) {
            $textureDiffs += [ordered]@{
                textureName = $name
                sha256Equal = $contentEqual
                decodedBytesEqual = $sizeEqual
                left = $leftDigest
                right = $rightDigest
            }
        }
    }

    foreach ($missingName in $leftOnlyTextures) {
        $textureDiffs += [ordered]@{ textureName = $missingName; missingIn = 'right'; left = $leftTextureMap[$missingName]; right = $null }
    }
    foreach ($missingName in $rightOnlyTextures) {
        $textureDiffs += [ordered]@{ textureName = $missingName; missingIn = 'left'; left = $null; right = $rightTextureMap[$missingName] }
    }

    if ($leftOnlyTextures.Count -gt 0 -or $rightOnlyTextures.Count -gt 0) {
        $differences += 'Texture name sets differ'
    }

    $result = [ordered]@{
        leftFile = $resolvedLeftPath
        rightFile = $resolvedRightPath
        equivalent = ($differences.Count -eq 0)
        textureCountLeft = $leftTextureMap.Count
        textureCountRight = $rightTextureMap.Count
        diff = [ordered]@{
            topLevelKeys = $topLevelDiff
            metadataPayload = $metaDiff
            characterData = $characterDiff
            textures = [ordered]@{
                leftOnly = $leftOnlyTextures
                rightOnly = $rightOnlyTextures
                mismatches = $textureDiffs
            }
        }
        differences = $differences
    }

    if (-not [string]::IsNullOrWhiteSpace($DiffReportPath)) {
        $writtenReportPath = Write-DiffReport -Path $DiffReportPath -Report $result
        Write-Host "[verify] Wrote diff report: $writtenReportPath"
    }

    if ($CiSummary) {
        $firstDiff = if ($differences.Count -gt 0) { [string]$differences[0] } else { '' }
        $summaryLine = 'VERIFY_RESULT equivalent={0} differences={1} texturesLeft={2} texturesRight={3} firstDifference="{4}"' -f $result.equivalent.ToString().ToLowerInvariant(), $differences.Count, $result.textureCountLeft, $result.textureCountRight, $firstDiff.Replace('"', '\\"')
        Write-Host $summaryLine
    }

    if ($result.equivalent) {
        Write-Stage -Prefix 'verify' -Message 'Files are semantically equivalent'
    }
    else {
        Write-Stage -Prefix 'verify' -Message 'Files are NOT semantically equivalent'
    }

    return $result
}
