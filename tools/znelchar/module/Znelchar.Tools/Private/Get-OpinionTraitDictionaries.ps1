<#
.SYNOPSIS
Loads opinion and trait ID-to-name dictionaries from the data directory.

.DESCRIPTION
Reads opinions.json and traits.json from the data directory and returns hashtables
for forward (ID->name) and reverse (name->ID) lookups.

.OUTPUTS
A hashtable containing:
- OpinionIdToName: Maps opinion IDs to display names
- OpinionNameToId: Maps display names to opinion IDs
- TraitIdToName: Maps trait IDs to display names
- TraitNameToId: Maps display names to trait IDs
#>
function Get-OpinionTraitDictionaries {
    [CmdletBinding()]
    param()

    # Navigate from module/Znelchar.Tools/Private/ up to tools/znelchar/data/
    $dataDir = Join-Path $PSScriptRoot '..' '..' '..' 'data'
    $dataDir = [System.IO.Path]::GetFullPath($dataDir)
    
    if (-not (Test-Path $dataDir)) {
        throw "Data directory not found at: $dataDir"
    }

    $opinionsFile = Join-Path $dataDir 'opinions.json'
    $traitsFile = Join-Path $dataDir 'traits.json'

    if (-not (Test-Path $opinionsFile)) {
        throw "Opinions dictionary not found at: $opinionsFile"
    }
    if (-not (Test-Path $traitsFile)) {
        throw "Traits dictionary not found at: $traitsFile"
    }

    # Load dictionaries
    $opinionsIdToName = Get-Content $opinionsFile -Raw | ConvertFrom-Json -AsHashtable
    $traitsIdToName = Get-Content $traitsFile -Raw | ConvertFrom-Json -AsHashtable

    # Create reverse lookups
    $opinionsNameToId = @{}
    foreach ($kvp in $opinionsIdToName.GetEnumerator()) {
        $opinionsNameToId[$kvp.Value] = $kvp.Key
    }

    $traitsNameToId = @{}
    foreach ($kvp in $traitsIdToName.GetEnumerator()) {
        $traitsNameToId[$kvp.Value] = $kvp.Key
    }

    return @{
        OpinionIdToName = $opinionsIdToName
        OpinionNameToId = $opinionsNameToId
        TraitIdToName   = $traitsIdToName
        TraitNameToId   = $traitsNameToId
    }
}
